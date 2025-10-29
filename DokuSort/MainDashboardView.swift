//
//  MainDashboardView.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI
import PDFKit

struct MainDashboardView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var analysis: AnalysisManager

    @State private var selection: DocumentItem?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                sidebar
                    .frame(minWidth: 260, idealWidth: 300, maxWidth: 340)
                    .background(.thinMaterial)

                Divider()

                preview
                    .frame(minWidth: 420)

                Divider()

                metadataPanel
                    .frame(minWidth: 420, idealWidth: 520)
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
                if settings.sourceBaseURL != nil && store.items.isEmpty {
                    store.scanSourceFolder(settings.sourceBaseURL)
                }
                autoSelectFirstIfNeeded()
            }
            .onReceive(NotificationCenter.default.publisher(for: .analysisDidFinish)) { note in
                if let url = note.object as? URL {
                    analysis.markAnalyzed(url)
                }
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Label("Intelligente Verarbeitung", systemImage: "wand.and.stars")
                    .font(.headline)

                let total = store.items.count
                let ratio = analysis.progress(total: total)
                HStack(spacing: 8) {
                    ProgressView(value: ratio)
                        .progressViewStyle(.linear)
                        .frame(maxWidth: 160)
                    Text("\(analysis.analyzed.count)/\(total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if total > 0 {
                    Text("Noch \(max(total - analysis.analyzed.count, 0)) Dokumente in der Warteschlange")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Suche (Platzhalter)
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Dokumente durchsuchen…", text: .constant(""))
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8).fill(.bar))
            .padding(.horizontal)

            // Liste
            List(store.items, selection: $selection) { item in
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName).lineLimit(1)
                        if let size = item.fileSize {
                            Text(byteCount(size)).font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Circle()
                        .fill(analysis.analyzed.contains(item.fileURL) ? .green.opacity(0.85) : .gray.opacity(0.35))
                        .frame(width: 8, height: 8)
                        .help(analysis.analyzed.contains(item.fileURL) ? "KI-analysiert" : "Wartend")
                }
                .contentShape(Rectangle())
                .onTapGesture { selection = item }
            }
            .listStyle(.plain)

            Spacer()

            HStack {
                Text("\(store.items.count) Dokumente").font(.caption).foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.bottom, 8)
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
                    embedPreview: false              // << hier ausschalten
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

    private func byteCount(_ bytes: Int64) -> String {
        let f = ByteCountFormatter()
        f.allowedUnits = [.useMB, .useKB]
        f.countStyle = .file
        return f.string(fromByteCount: bytes)
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
