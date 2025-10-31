//
//  BackgroundAnalyzer.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import PDFKit
import Combine

/// Arbeitet beim App-Start die komplette Quelle ab und verarbeitet danach laufend neue Dateien.
/// Single-Worker-Queue, damit CPU/Memory stabil bleiben.
@MainActor
final class BackgroundAnalyzer: ObservableObject {

    private weak var store: DocumentStore?
    private weak var settings: SettingsStore?
    private weak var analysis: AnalysisManager?

    // Warteschlange + Set gegen doppelte Verarbeitung
    private var queue: [URL] = []
    private var enqueued: Set<String> = []

    // Worker-Steuerung
    private var isRunning = false
    private var observers: [AnyCancellable] = []

    // Public API: Initialisierung/Start
    func start(store: DocumentStore, settings: SettingsStore, analysis: AnalysisManager) {
        self.store = store
        self.settings = settings
        self.analysis = analysis

        // Beim Start: initial alles einreihen
        enqueueAllPendingFromStore()

        // Quelle aendert sich? → neu scannen + einreihen
        NotificationCenter.default.publisher(for: .sourceFolderDidChange)
            .sink { [weak self] _ in
                guard let self else { return }
                self.store?.scanSourceFolder(self.settings?.sourceBaseURL)
                self.enqueueAllPendingFromStore()
                self.kickWorker()
            }
            .store(in: &observers)

        // Datei wurde erfolgreich analysiert (aus UI oder Background) → Queue aufraeumen
        NotificationCenter.default.publisher(for: .analysisDidFinish)
            .sink { [weak self] note in
                guard let self, let url = note.object as? URL else { return }
                let normalized = url.normalizedFileURL
                self.enqueued.remove(normalized.path)
                self.queue.removeAll { $0 == normalized }
            }
            .store(in: &observers)

        // Nach Ablage entfernen (damit die Queue sauber bleibt)
        NotificationCenter.default.publisher(for: .documentDidArchive)
            .sink { [weak self] note in
                guard let self, let url = note.object as? URL else { return }
                let normalized = url.normalizedFileURL
                self.enqueued.remove(normalized.path)
                self.queue.removeAll { $0 == normalized }
            }
            .store(in: &observers)

        // Wenn Quelle in den Einstellungen umgestellt wird
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                // konservativ: neu scannen + neu einreihen
                self?.store?.scanSourceFolder(self?.settings?.sourceBaseURL)
                self?.enqueueAllPendingFromStore()
                self?.kickWorker()
            }
            .store(in: &observers)

        // Worker anschieben
        kickWorker()
    }

    // MARK: Queueing

    /// Alle Dateien aus dem Store einreihen, die noch nicht (persistiert) analysiert sind.
    private func enqueueAllPendingFromStore() {
        guard let store, let analysis else { return }
        for item in store.items {
            let normalizedURL = item.fileURL.normalizedFileURL
            let path = normalizedURL.path
            // Bereits abgelegt/analysiert? → ueberspringen
            if analysis.isAnalyzed(normalizedURL) { continue }
            // Bereits in der Queue? → ueberspringen
            if enqueued.contains(path) { continue }
            // Einreihen
            enqueued.insert(path)
            queue.append(normalizedURL)
        }
    }

    /// Ein einzelnes URL einreihen (z. B. aus Watcher-Ereignis in Zukunft)
    private func enqueue(_ url: URL) {
        let normalizedURL = url.normalizedFileURL
        let path = normalizedURL.path
        if enqueued.contains(path) { return }
        enqueued.insert(path)
        queue.append(normalizedURL)
    }

    // MARK: Worker

    private func kickWorker() {
        guard !isRunning else { return }
        isRunning = true
        Task {
            defer { isRunning = false }
            while let url = nextJob() {
                await process(url)
                // kleine Verschnaufpause, damit System ruhig bleibt
                try? await Task.sleep(nanoseconds: 150_000_000) // 150ms
            }
        }
    }

    private func nextJob() -> URL? {
        while !queue.isEmpty {
            let url = queue.removeFirst()
            // Existiert die Datei noch?
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            } else {
                enqueued.remove(url.path)
            }
        }
        return nil
    }

    // MARK: Verarbeitung

    private func process(_ url: URL) async {
        guard let settings, let analysis else { return }
        // Falls inzwischen bereits analysiert → ueberspringen
        if analysis.isAnalyzed(url) { return }

        // 1) Eingebetteten Text lesen
        let embedded = extractPDFText(url: url) ?? ""

        // 2) OLLAMA zuerst, falls Text vorhanden
        if !embedded.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let s = try? await OllamaClient.suggest(from: embedded,
                                                       baseURL: settings.ollamaBaseURL,
                                                       model: settings.ollamaModel),
               hasUsefulValues(s) {
                publish(url: url, suggestion: s)
                return
            }
        }

        // 3) OCR-Volltext
        if let ocrText = try? await OCRService.recognizeFullText(pdfURL: url),
           !ocrText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            if let s2 = try? await OllamaClient.suggest(from: ocrText,
                                                        baseURL: settings.ollamaBaseURL,
                                                        model: settings.ollamaModel),
               hasUsefulValues(s2) {
                publish(url: url, suggestion: s2)
                return
            }
        }

        // 4) Fallback: heuristische OCR-Vorschlaege
        if let s3 = try? await OCRService.suggest(from: url) {
            publish(url: url, suggestion: s3)
            return
        }

        // 5) Gescheitert
        analysis.markFailed(url: url)
        NotificationCenter.default.post(name: .analysisDidFail, object: url)
    }

    // MARK: Util

    private func extractPDFText(url: URL) -> String? {
        guard let doc = PDFDocument(url: url) else { return nil }
        var out = ""
        for i in 0..<min(doc.pageCount, 6) {
            guard let page = doc.page(at: i), let s = page.string else { continue }
            out.append(s + "\n")
            if out.count > 8_000 { break }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasUsefulValues(_ s: Suggestion) -> Bool {
        (s.datum != nil) || (s.korrespondent?.isEmpty == false) || (s.dokumenttyp?.isEmpty == false)
    }

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

    private func publish(url: URL, suggestion: Suggestion) {
        // AnalyseState bauen inkl. Dateifacts
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let state = AnalysisState(
            status: .analyzed,
            confidence: confidence(for: suggestion),
            korrespondent: suggestion.korrespondent,
            dokumenttyp: suggestion.dokumenttyp,
            datum: suggestion.datum,
            fileSize: values?.fileSize.map(Int64.init),
            fileModDate: values?.contentModificationDate
        )

        // UI informieren → AnalysisManager wird via Notification speichern
        NotificationCenter.default.post(name: .analysisDidFinish, object: url, userInfo: ["state": state])
    }
}
