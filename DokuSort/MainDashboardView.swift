//
//  MainDashboardView.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI
import PDFKit
import Combine

struct MainDashboardView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var analysis: AnalysisManager

    @State private var selection: DocumentItem?
    @State private var showSettings = false

    // Suche + Filter
    @State private var searchText: String = ""
    enum StatusFilter: String, CaseIterable, Identifiable { case all = "Alle", pending = "Wartend", analyzed = "Analysiert"
        var id: String { rawValue } }
    @State private var statusFilter: StatusFilter = .all

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(minWidth: 280, idealWidth: 320, maxWidth: 360)
                    .background(.thinMaterial)

                Divider()

                preview
                    .frame(minWidth: 460)

                Divider()

                metadataPanel
                    .frame(minWidth: 440, idealWidth: 540)
            }
            .navigationTitle("DokuSort Dashboard")
            .toolbar {
                ToolbarItem {
                    Button {
                        store.scanSourceFolder(settings.sourceBaseURL)
                        analysis.reset()
                        autoSelectFirstIfNeeded()
                    } label: {
                        Label("Quelle scannen", systemImage: "tray.full")
                    }
                }
                ToolbarItem {
                    Button { showSettings = true } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                AppSettingsSheet().environmentObject(settings)
            }
            .onAppear {
                // Immer Quelle scannen und States laden beim Öffnen
                if settings.sourceBaseURL != nil {
                    if store.items.isEmpty {
                        store.scanSourceFolder(settings.sourceBaseURL)
                    }
                    // WICHTIG: States aus Persistenz laden (auch wenn bereits im Cache)
                    analysis.preloadStates(for: store.items.map { $0.fileURL })
                }
                autoSelectFirstIfNeeded()
            }

            .onAppear {
                if let window = NSApp.keyWindow {
                    WindowManager.shared.registerMainWindow(window)
                }
            }
            // Analyse-Resultate übernehmen
            .onReceive(NotificationCenter.default.publisher(for: .documentDidArchive)) { note in
                if let url = note.object as? URL {
                    let normalizedURL = url.normalizedFileURL
                    analysis.remove(url: normalizedURL)
                    // Store neu scannen nach Ablage
                    store.scanSourceFolder(settings.sourceBaseURL)
                }
            }

            .onReceive(NotificationCenter.default.publisher(for: .analysisDidFinish)) { note in
                guard let url = note.object as? URL else { return }
                let normalizedURL = url.normalizedFileURL

                if let st = note.userInfo?["state"] as? AnalysisState {
                    analysis.markAnalyzed(url: normalizedURL, state: st)
                } else {
                    // Fallback: aus Persistenz laden
                    if let st = analysis.state(for: normalizedURL) {
                        analysis.markAnalyzed(url: normalizedURL, state: st)
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .analysisDidFail)) { note in
                if let url = note.object as? URL {
                    let normalizedURL = url.normalizedFileURL
                    analysis.markFailed(url: normalizedURL)
                }
            }
            // NEU: Live-Refresh bei Änderungen im Quellordner
            .onReceive(NotificationCenter.default.publisher(for: .sourceFolderDidChange)) { _ in
                store.scanSourceFolder(settings.sourceBaseURL)
                analysis.preloadStates(for: store.items.map { $0.fileURL })
                // Auswahl sanft stabil halten: wenn altes File weg ist, ersten Eintrag wählen
                if let sel = selection, !store.items.contains(sel) {
                    selection = store.items.first
                }
            }
            .onReceive(store.$items) { items in
                // Bei Änderungen der Items: States neu laden
                analysis.preloadStates(for: items.map { $0.fileURL })
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kopf + Fortschritt
            VStack(alignment: .leading, spacing: 8) {
                Label("Intelligente Verarbeitung", systemImage: "wand.and.stars")
                    .font(.headline)

                let total = store.items.count
                let ratio = analysis.progress(total: total)
                HStack(spacing: 8) {
                    ProgressView(value: ratio)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 180)
                    Text("\(analysis.analyzedCount)/\(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if total > 0 {
                    Text("Noch \(max(total - analysis.analyzedCount, 0)) in Warteschlange")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Suche
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Dokumente durchsuchen…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.bar))
            .padding(.horizontal)

            // Filter (Status)
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Liste (gefiltert)
            List(filteredItems, selection: $selection) { item in
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName).lineLimit(1)
                        HStack(spacing: 8) {
                            if let st = analysis.state(for: item.fileURL) {
                                ConfidenceBar(value: st.confidence)
                                if let typ = st.dokumenttyp, !typ.isEmpty {
                                    TypeBadge(typ)
                                }
                            } else {
                                ConfidenceBar(value: 0)
                            }
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(analysis.isAnalyzed(item.fileURL) ? .green.opacity(0.85) : .gray.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .help(analysis.isAnalyzed(item.fileURL) ? "KI-analysiert" : "Wartend")
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = item }
            }
            .listStyle(.plain)

            Spacer()

            HStack {
                Text("\(filteredItems.count) Treffer").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
        }
    }

    // Gefilterte Items
    private var filteredItems: [DocumentItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.items.filter { item in
            // Statusfilter
            switch statusFilter {
            case .all:      break
            case .pending:  if analysis.isAnalyzed(item.fileURL) { return false }
            case .analyzed: if !analysis.isAnalyzed(item.fileURL) { return false }
            }
            // Textsuche (Dateiname + erkannte Felder)
            if q.isEmpty { return true }
            if item.fileName.lowercased().contains(q) { return true }
            if let st = analysis.state(for: item.fileURL) {
                if (st.korrespondent ?? "").lowercased().contains(q) { return true }
                if (st.dokumenttyp ?? "").lowercased().contains(q) { return true }
                if let d = st.datum {
                    let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
                    if f.string(from: d).contains(q) { return true }
                }
            }
            return false
        }
    }

    // MARK: Mitte

    private var preview: some View {
        Group {
            if let sel = selection {
                PDFKitNSView(url: sel.fileURL)
                    .background(Color(nsColor: .underPageBackgroundColor))
            } else {
                placeholder("Kein Dokument ausgewählt", sub: "Wähle links ein PDF, um die Vorschau anzuzeigen.")
            }
        }
    }

    // MARK: Rechts: echter Editor

    private var metadataPanel: some View {
        Group {
            if let sel = selection {
                MetadataEditorView(
                    item: sel,
                    onPrev: { selection = prev(of: sel) },
                    onNext: { selection = next(of: sel) },
                    embedPreview: false
                )
            } else {
                placeholder("Bereit", sub: "Sobald ein PDF gewählt ist, erscheinen hier die erkannten Daten.")
            }
        }
    }

    // MARK: Helpers

    private func autoSelectFirstIfNeeded() {
        if selection == nil, let first = store.items.first {
            selection = first
        }
    }

    private func next(of item: DocumentItem) -> DocumentItem? {
        guard let idx = store.items.firstIndex(of: item) else { return nil }
        let ni = idx + 1
        return ni < store.items.count ? store.items[ni] : nil
    }

    private func prev(of item: DocumentItem) -> DocumentItem? {
        guard let idx = store.items.firstIndex(of: item) else { return nil }
        let pi = idx - 1
        return pi >= 0 ? store.items[pi] : nil
    }

    private func placeholder(_ title: String, sub: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "rectangle.and.text.magnifyingglass").font(.system(size: 40))
            Text(title).font(.headline)
            Text(sub).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

// Mini-Konfidenz-Balken
private struct ConfidenceBar: View {
    var value: Double // 0...1
    var body: some View {
        GeometryReader { geo in
            let w = max(0, min(geo.size.width * value, geo.size.width))
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3).fill(.gray.opacity(0.2))
                RoundedRectangle(cornerRadius: 3).fill( value >= 0.7 ? .green.opacity(0.6) : (value >= 0.35 ? .orange.opacity(0.6) : .red.opacity(0.6)) )
                    .frame(width: w)
            }
        }
        .frame(width: 60, height: 6)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .help("Konfidenz: \((Int(value * 100)))%")
    }
}

// Typ-Badge
private struct TypeBadge: View {
    let type: String
    init(_ t: String) { self.type = t }
    var body: some View {
        Text(type)
            .font(.caption2)
            .padding(.vertical, 3)
            .padding(.horizontal, 6)
            .background(
                Capsule().fill(colorFor(type).opacity(0.18))
            )
            .overlay(
                Capsule().stroke(colorFor(type).opacity(0.35), lineWidth: 0.5)
            )
    }
    private func colorFor(_ t: String) -> Color {
        let l = t.lowercased()
        if l.contains("rechnung") { return .blue }
        if l.contains("mahnung")  { return .red }
        if l.contains("police")   { return .green }
        if l.contains("vertrag")  { return .purple }
        if l.contains("offerte")  { return .orange }
        if l.contains("gutschrift"){ return .teal }
        if l.contains("liefer")   { return .indigo }
        return .gray
    }
}
