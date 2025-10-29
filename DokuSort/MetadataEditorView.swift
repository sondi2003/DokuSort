import SwiftUI
import PDFKit

// Identifiable-Wrapper für .sheet(item:)
private struct ConflictBox: Identifiable {
    let id = UUID()
    let url: URL
}

struct MetadataEditorView: View {
    let item: DocumentItem
    var onPrev: (() -> Void)? = nil
    var onNext: (() -> Void)? = nil
    /// Wenn false: keine eigene PDF-Vorschau im Editor (im Dashboard nutzen wir die grosse Mitte)
    var embedPreview: Bool = true

    @EnvironmentObject private var catalog: CatalogStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var store: DocumentStore

    @State private var meta = DocumentMetadata.empty()
    @State private var korInput: String = ""
    @State private var typInput: String = ""
    @State private var showKorSuggestions = false
    @State private var showTypSuggestions = false

    @State private var running = false
    @State private var alertMsg: String?
    @ObservedObject private var undoStore = UndoStore.shared

    @State private var conflictBox: ConflictBox? = nil
    @State private var pendingNextAfter = false

    // Statusbanner + Infos zur letzten Analyse
    @State private var statusText: String? = nil
    @State private var lastSuggestion: Suggestion? = nil

    var body: some View {
        ZStack(alignment: .top) {
            HStack(spacing: 0) {
                if embedPreview {
                    PDFKitNSView(url: item.fileURL)
                        .frame(minWidth: 380)
                    Divider()
                }

                VStack(alignment: .leading, spacing: 12) {
                    // Navigation für Batch
                    HStack(spacing: 12) {
                        Button { onPrev?() } label: { Label("Vorheriges", systemImage: "chevron.left") }
                            .disabled(onPrev == nil || running)
                        Button { onNext?() } label: { Label("Nächstes", systemImage: "chevron.right") }
                            .disabled(onNext == nil || running)
                        Spacer()
                    }

                    Text("Metadaten").font(.title2).bold()
                    DatePicker("Datum", selection: $meta.datum, displayedComponents: .date)

                    // Korrespondent
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Korrespondent")
                        TextField("z. B. Krankenkasse XY", text: $korInput, onEditingChanged: { editing in
                            showKorSuggestions = editing
                        })
                        .textFieldStyle(.roundedBorder)

                        if showKorSuggestions {
                            let sugg = catalog.suggestions(for: korInput, in: .korrespondent)
                            if !sugg.isEmpty {
                                List(sugg, id: \.self) { s in
                                    Button(s) { korInput = s; showKorSuggestions = false }
                                        .buttonStyle(.plain)
                                }
                                .frame(maxHeight: 140)
                            }
                        }
                    }

                    // Dokumenttyp
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Dokumenttyp")
                        TextField("z. B. Rechnung, Police, Vertrag", text: $typInput, onEditingChanged: { editing in
                            showTypSuggestions = editing
                        })
                        .textFieldStyle(.roundedBorder)

                        if showTypSuggestions {
                            let sugg = catalog.suggestions(for: typInput, in: .dokumenttyp)
                            if !sugg.isEmpty {
                                List(sugg, id: \.self) { s in
                                    Button(s) { typInput = s; showTypSuggestions = false }
                                        .buttonStyle(.plain)
                                }
                                .frame(maxHeight: 140)
                            }
                        }
                    }

                    if let s = lastSuggestion {
                        GroupBox("Erkannte Werte") {
                            VStack(alignment: .leading, spacing: 4) {
                                if let d = s.datum { Text("Datum: \(formatDate(d))") }
                                if let k = s.korrespondent, !k.isEmpty { Text("Korrespondent: \(k)") }
                                if let t = s.dokumenttyp, !t.isEmpty { Text("Dokumenttyp: \(t)") }
                                Text("Werte wurden automatisch übernommen. Bitte ggf. korrigieren.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(6)
                        }
                    }

                    Divider().padding(.vertical, 4)

                    // Archiv-Basisordner
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Archiv-Basisordner")
                        HStack {
                            Text(settings.archiveBaseURL?.path ?? "Kein Ordner gewählt")
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(settings.archiveBaseURL == nil ? .secondary : .primary)
                            Spacer()
                            Button { settings.chooseArchiveBaseFolder() } label: { Label("Wählen", systemImage: "folder") }
                                .disabled(running)
                        }
                    }

                    // Dry-Run
                    GroupBox("Ablage-Preview (Dry-Run)") {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Zielordner:").bold()
                            Text(dryRunTargetDir().path).font(.callout).textSelection(.enabled).lineLimit(2)
                            Text("Dateiname:").bold()
                            Text(dryRunFileName()).font(.callout).textSelection(.enabled)
                            if settings.archiveBaseURL == nil {
                                Label("Bitte Archiv-Basisordner wählen.", systemImage: "exclamationmark.triangle").foregroundStyle(.orange)
                            }
                        }
                        .padding(6)
                    }

                    Spacer()

                    HStack {
                        Button { persistInputsToCatalog() } label: { Label("Angaben übernehmen", systemImage: "checkmark.circle") }
                            .disabled(running)

                        Spacer()

                        Button { doPlace(nextAfter: false) } label: {
                            running ? AnyView(ProgressView().controlSize(.small))
                                    : AnyView(Label("Ablage ausführen", systemImage: "externaldrive.badge.checkmark"))
                        }
                        .disabled(running || settings.archiveBaseURL == nil)

                        Button { doPlace(nextAfter: true) } label: {
                            running ? AnyView(ProgressView().controlSize(.small))
                                    : AnyView(Label("Ablage & Nächstes", systemImage: "arrow.right.circle"))
                        }
                        .disabled(running || settings.archiveBaseURL == nil)
                    }

                    HStack {
                        if undoStore.lastAction != nil {
                            Button { doUndo() } label: { Label("Rückgängig", systemImage: "arrow.uturn.backward") }
                                .disabled(running)
                        }
                        Spacer()
                    }
                }
                .padding()
                .frame(minWidth: 520)
            }

            // STATUSBANNER
            if let text = statusText {
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text(text).font(.callout).bold()
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 12)
                .background(.ultraThickMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.secondary.opacity(0.4), lineWidth: 0.5))
                .padding(.top, 8)
            }
        }
        .onAppear {
            // Felder leeren und frisches Datum setzen
            korInput = ""
            typInput = ""
            meta = .empty()
        }
        // Automatische Analyse: bei jedem neuen Item starten
        .task(id: item.fileURL) {
            await runAutoSuggestionAndApply()
        }
        .navigationTitle(item.fileName)
        .alert(item: Binding(get: { alertMsg.map { MsgWrapper(message: $0) } }, set: { _ in alertMsg = nil })) { w in
            Alert(title: Text(w.message))
        }
        .sheet(item: $conflictBox) { box in
            ConflictResolutionSheet(conflictedURL: box.url) { choice in
                conflictBox = nil
                guard let base = settings.archiveBaseURL else { return }
                guard let choice = choice else { return }
                doPlaceInternal(base: base, conflictPolicy: choice, nextAfter: pendingNextAfter)
            }
        }
    }

    // MARK: Analyse (Ollama zuerst, dann OCR-Fallback) + Auto-Übernahme
    /// Sendet bei Erfolg .analysisDidFinish mit AnalysisState (inkl. confidence); bei Fehler .analysisDidFail.
    private func runAutoSuggestionAndApply() async {
        // Schutz: nicht doppelt analysieren
        if running { return }
        running = true
        statusText = "Analysiere mit KI, bitte warten …"
        defer {
            running = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { statusText = nil }
        }

        do {
            // 1) Versuche eingebetteten PDF-Text
            let embedded = extractPDFText(url: item.fileURL) ?? ""

            // 2) OLLAMA mit eingebettetem Text
            if !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if let s = try? await OllamaClient.suggest(from: embedded,
                                                           baseURL: settings.ollamaBaseURL,
                                                           model: settings.ollamaModel),
                   hasUsefulValues(s) {
                    applySuggestionOverwriting(s)
                    lastSuggestion = s
                    statusText = "KI-Ergebnis übernommen"

                    let st = AnalysisState(
                        status: .analyzed,
                        confidence: confidence(for: s),
                        korrespondent: s.korrespondent,
                        dokumenttyp: s.dokumenttyp,
                        datum: s.datum
                    )
                    NotificationCenter.default.post(name: .analysisDidFinish, object: item.fileURL, userInfo: ["state": st])
                    return
                }
            }

            // 3) OCR-Volltext erzeugen
            statusText = "Kein Text eingebettet – OCR wird ausgeführt …"
            let ocrText = try? await OCRService.recognizeFullText(pdfURL: item.fileURL)

            // 4) OLLAMA mit OCR-Text
            if let ocrText, !ocrText.isEmpty {
                if let s2 = try? await OllamaClient.suggest(from: ocrText,
                                                            baseURL: settings.ollamaBaseURL,
                                                            model: settings.ollamaModel),
                   hasUsefulValues(s2) {
                    applySuggestionOverwriting(s2)
                    lastSuggestion = s2
                    statusText = "KI-Ergebnis (OCR) übernommen"

                    let st = AnalysisState(
                        status: .analyzed,
                        confidence: confidence(for: s2),
                        korrespondent: s2.korrespondent,
                        dokumenttyp: s2.dokumenttyp,
                        datum: s2.datum
                    )
                    NotificationCenter.default.post(name: .analysisDidFinish, object: item.fileURL, userInfo: ["state": st])
                    return
                }
            }

            // 5) Fallback: rein heuristische OCR-Vorschläge
            statusText = "KI ohne klaren Treffer – nutze OCR-Heuristik …"
            let s3 = try await OCRService.suggest(from: item.fileURL)
            applySuggestionOverwriting(s3)
            lastSuggestion = s3
            statusText = "OCR-Ergebnis übernommen"

            let st = AnalysisState(
                status: .analyzed,
                confidence: confidence(for: s3),
                korrespondent: s3.korrespondent,
                dokumenttyp: s3.dokumenttyp,
                datum: s3.datum
            )
            NotificationCenter.default.post(name: .analysisDidFinish, object: item.fileURL, userInfo: ["state": st])

        } catch {
            alertMsg = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
            statusText = "Analyse fehlgeschlagen"
            NotificationCenter.default.post(name: .analysisDidFail, object: item.fileURL)
        }
    }

    private func hasUsefulValues(_ s: Suggestion) -> Bool {
        (s.datum != nil) || (s.korrespondent?.isEmpty == false) || (s.dokumenttyp?.isEmpty == false)
    }

    /// einfache Konfidenz-Heuristik 0...1
    private func confidence(for s: Suggestion) -> Double {
        var c: Double = 0
        if s.korrespondent?.isEmpty == false { c += 0.33 }
        if s.dokumenttyp?.isEmpty == false { c += 0.33 }
        if s.datum != nil { c += 0.33 }
        let lower = (s.dokumenttyp ?? "").lowercased()
        if ["rechnung","mahnung","police","vertrag","offerte","gutschrift","lieferschein"].contains(where: { lower.contains($0) }) {
            c += 0.05
        }
        return min(c, 1.0)
    }

    private func applySuggestionOverwriting(_ s: Suggestion) {
        if let d = s.datum { meta.datum = d }
        if let k = s.korrespondent { korInput = k }
        if let t = s.dokumenttyp { typInput = t }
        // Sofort in Katalog mitschreiben (lernt schneller)
        persistInputsToCatalog()
    }

    // MARK: Ablage / Undo

    private func persistInputsToCatalog() {
        meta.korrespondent = korInput.trimmingCharacters(in: .whitespacesAndNewlines)
        meta.dokumenttyp = typInput.trimmingCharacters(in: .whitespacesAndNewlines)
        if !meta.korrespondent.isEmpty { catalog.addKorrespondent(meta.korrespondent) }
        if !meta.dokumenttyp.isEmpty { catalog.addDokumenttyp(meta.dokumenttyp) }
    }

    private func doPlace(nextAfter: Bool) {
        guard let base = settings.archiveBaseURL else { alertMsg = "Bitte zuerst den Archiv-Basisordner wählen."; return }
        persistInputsToCatalog()
        pendingNextAfter = nextAfter
        doPlaceInternal(base: base, conflictPolicy: settings.conflictPolicy, nextAfter: nextAfter)
    }

    private func doPlaceInternal(base: URL, conflictPolicy: ConflictPolicy, nextAfter: Bool) {
        running = true
        statusText = "Ablage läuft …"
        defer {
            running = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { statusText = nil }
        }
        do {
            let result = try FileOps.place(item: item,
                                           meta: meta,
                                           archiveBaseURL: base,
                                           mode: settings.currentPlaceMode(),
                                           conflictPolicy: conflictPolicy)
            UndoStore.shared.registerMove(from: result.sourceURL, to: result.finalURL)
            store.scanSourceFolder(settings.sourceBaseURL)
            alertMsg = "Ablage erfolgreich: \(result.finalURL.lastPathComponent)"
            if nextAfter { onNext?() }
        } catch let err as FileOpsError {
            switch err {
            case .nameConflict(let url):
                conflictBox = ConflictBox(url: url)
            default:
                alertMsg = err.errorDescription ?? "\(err)"
            }
        } catch {
            alertMsg = error.localizedDescription
        }
    }

    private func doUndo() {
        do {
            try UndoStore.shared.undoLastMove()
            store.scanSourceFolder(settings.sourceBaseURL)
            alertMsg = "Letzte Ablage wurde rückgängig gemacht."
        } catch {
            alertMsg = "Rückgängig fehlgeschlagen: \(error.localizedDescription)"
        }
    }

    // MARK: Helpers

    private func extractPDFText(url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var out = ""
        for i in 0..<min(doc.pageCount, 6) {
            guard let page = doc.page(at: i), let s = page.string else { continue }
            out.append(s + "\n")
            if out.count > 8000 { break }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func dryRunTargetDir() -> URL {
        let base = settings.archiveBaseURL ?? URL(fileURLWithPath: "/Archiv/BitteOrdnerWaehlen")
        let korr = sanitize(korInput.isEmpty ? "Unbekannt" : korInput, allowSpaces: true)
        let jahr = meta.jahr
        return base.appendingPathComponent(korr).appendingPathComponent(jahr)
    }

    private func dryRunFileName() -> String {
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let dateStr = df.string(from: meta.datum)
        let typ = sanitize(typInput.isEmpty ? "Dokument" : typInput, allowSpaces: true)
        return "\(dateStr)_\(typ).pdf"
    }

    private func sanitize(_ s: String, allowSpaces: Bool) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        var out = s.components(separatedBy: invalid).joined(separator: "_")
        if !allowSpaces { out = out.replacingOccurrences(of: " ", with: "_") }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? "Unbenannt" : out
    }

    private func formatDate(_ d: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: d)
    }

    private struct MsgWrapper: Identifiable { let id = UUID(); let message: String }
}

// macOS PDFKit Wrapper (nur EINMAL im Projekt definieren!)
struct PDFKitNSView: NSViewRepresentable {
    let url: URL
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.document = PDFDocument(url: url)
        return pdfView
    }
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}

private extension View {
    func eraseToAnyView() -> AnyView { AnyView(self) }
}
