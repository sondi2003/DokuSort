//
//  MainDashboardView.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI
import PDFKit
import Combine
import AppKit

struct MainDashboardView: View {
    @EnvironmentObject private var store: DocumentStore
    @EnvironmentObject private var settings: SettingsStore
    // @EnvironmentObject private var analysis: AnalysisManager // Vorerst deaktiviert, da wir den neuen Service nutzen

    @State private var selection: DocumentItem?
    @State private var showSettings = false
    
    // Suche + Filter
    @State private var searchText: String = ""
    
    // Lokale Hilfs-States für die Filterung (da AnalysisManager noch umgebaut wird, nutzen wir die Daten im DocumentItem)
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case pending = "Wartend"
        case analyzed = "Analysiert"
        var id: String { rawValue }
    }
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
                autoSelectFirstIfNeeded()
                if let window = NSApp.keyWindow {
                    WindowManager.shared.registerMainWindow(window)
                }
            }
        }
    }

    // MARK: Sidebar

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Kopf
            VStack(alignment: .leading, spacing: 8) {
                Label("Intelligente Verarbeitung", systemImage: "wand.and.stars")
                    .font(.headline)

                Text("\(store.items.count) Dokumente")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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

            // Filter
            Picker("Status", selection: $statusFilter) {
                ForEach(StatusFilter.allCases) { f in
                    Text(f.rawValue).tag(f)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Liste
            List(filteredItems, selection: $selection) { item in
                HStack(spacing: 12) {
                    Image(systemName: "doc.text")

                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.fileName).lineLimit(1)
                        HStack(spacing: 8) {
                            // Anzeige basierend auf neuen Metadaten im DocumentItem
                            if !item.correspondent.isEmpty {
                                Text(item.correspondent)
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                            if !item.tags.isEmpty {
                                TypeBadge(item.tags.first ?? "")
                            }
                        }
                    }
                    Spacer()
                    Circle()
                        // Grün, wenn Metadaten vorhanden sind
                        .fill((!item.correspondent.isEmpty) ? .green.opacity(0.85) : .gray.opacity(0.35))
                        .frame(width: 8, height: 8)
                }
                .tag(item) // Wichtig für Selection
                .contentShape(Rectangle())
                .onTapGesture { selection = item }
            }
            .listStyle(.plain)

            Spacer()
        }
    }

    // Gefilterte Items
    private var filteredItems: [DocumentItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.items.filter { item in
            // Statusfilter (einfache Logik: hat Korrespondent = analysiert)
            let isAnalyzed = !item.correspondent.isEmpty
            switch statusFilter {
            case .all:      break
            case .pending:  if isAnalyzed { return false }
            case .analyzed: if !isAnalyzed { return false }
            }
            
            // Textsuche
            if q.isEmpty { return true }
            if item.fileName.lowercased().contains(q) { return true }
            if item.correspondent.lowercased().contains(q) { return true }
            if item.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
            
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

    // MARK: Rechts: Neuer Editor

    private var metadataPanel: some View {
        Group {
            if let sel = selection {
                // KORREKTUR: Aufruf an die neue API angepasst
                MetadataEditorView(item: sel)
                    .id(sel.id) // Neu rendern bei Wechsel
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

// MARK: - Helper Views

// Fehlende PDFKitNSView nachgereicht
struct PDFKitNSView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
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
            .background(Capsule().fill(colorFor(type).opacity(0.18)))
            .overlay(Capsule().stroke(colorFor(type).opacity(0.35), lineWidth: 0.5))
    }
    private func colorFor(_ t: String) -> Color {
        let l = t.lowercased()
        if l.contains("rechnung") { return .blue }
        if l.contains("mahnung")  { return .red }
        if l.contains("police")   { return .green }
        if l.contains("vertrag")  { return .purple }
        if l.contains("offerte")  { return .orange }
        return .gray
    }
}
