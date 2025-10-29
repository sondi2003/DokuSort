//
//  ContentView.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var settings: SettingsStore

    @State private var selection: DocumentItem?
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if store.items.isEmpty {
                    emptyState
                } else {
                    listView
                }
            }
            .navigationTitle("DokuSort")
            .toolbar {
                ToolbarItem {
                    Button {
                        store.scanSourceFolder(settings.sourceBaseURL)
                    } label: {
                        Label("Quelle scannen", systemImage: "tray.full")
                    }
                }
                ToolbarItem {
                    Button {
                        showSettings = true
                    } label: {
                        Label("Einstellungen", systemImage: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                AppSettingsSheet().environmentObject(settings)
            }
            .onAppear {
                if settings.sourceBaseURL != nil {
                    store.scanSourceFolder(settings.sourceBaseURL)
                }
            }
            .navigationDestination(item: $selection) { item in
                MetadataEditorView(
                    item: item,
                    onPrev: { selection = previousItem(for: item) },
                    onNext: {
                        selection = nextItem(for: item)
                        // Nach Ablage/Wechsel ggf. Liste neu laden
                        store.scanSourceFolder(settings.sourceBaseURL)
                    }
                )
            }
        }
    }

    // MARK: Views

    private var listView: some View {
        List(store.items, selection: $selection) { item in
            NavigationLink(value: item) {
                HStack {
                    Image(systemName: "doc.richtext")
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName).lineLimit(1)
                        if let size = item.fileSize {
                            Text(byteCount(size))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray.and.arrow.down.fill").font(.system(size: 48))
            Text("Keine PDFs in der Quelle").font(.title2)
            Text("Lege PDFs in den definierten Quellordner und klicke auf „Quelle scannen“.").multilineTextAlignment(.center).foregroundStyle(.secondary)
        }.padding()
    }

    // MARK: Helpers

    private func byteCount(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func index(of item: DocumentItem) -> Int? {
        store.items.firstIndex(of: item)
    }
    private func nextItem(for item: DocumentItem) -> DocumentItem? {
        guard let i = index(of: item) else { return nil }
        let ni = i + 1
        return ni < store.items.count ? store.items[ni] : nil
    }
    private func previousItem(for item: DocumentItem) -> DocumentItem? {
        guard let i = index(of: item) else { return nil }
        let pi = i - 1
        return pi >= 0 ? store.items[pi] : nil
    }
}
