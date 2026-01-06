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
    
    @State private var selection: DocumentItem?
    
    // Suche + Filter
    @State private var searchText: String = ""
    enum StatusFilter: String, CaseIterable, Identifiable {
        case all = "Alle"
        case pending = "Neu"
        case analyzed = "Fertig"
        var id: String { rawValue }
    }
    @State private var statusFilter: StatusFilter = .all

    var body: some View {
        // Wir nutzen hier HStack für das 3-Spalten-Layout.
        // Das ist stabil und sieht mit den Dividern aus wie eine SplitView.
        HStack(spacing: 0) {
            // SPALTE 1: SIDEBAR
            sidebar
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 350)
                .background(.ultraThinMaterial) // Der moderne Glass-Look
            
            Divider()
            
            // SPALTE 2: PREVIEW
            preview
                .frame(minWidth: 400)
            
            Divider()
            
            // SPALTE 3: EDITOR (Metadaten)
            metadataPanel
                .frame(minWidth: 350, idealWidth: 400)
                .background(Color(nsColor: .controlBackgroundColor))
        }
        .frame(minWidth: 1000, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    store.scanSourceFolder(settings.sourceBaseURL)
                }) {
                    Label("Aktualisieren", systemImage: "arrow.clockwise")
                }
                .help("Quelle neu scannen")
            }
        }
        .onAppear {
            if let window = NSApp.keyWindow {
                WindowManager.shared.registerMainWindow(window)
            }
            if store.items.isEmpty && settings.sourceBaseURL != nil {
                 store.scanSourceFolder(settings.sourceBaseURL)
            }
        }
        .onChange(of: store.items) { oldItems, newItems in
            handleItemsChange(oldItems: oldItems, newItems: newItems)
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header Area
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "tray.full.fill")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Eingang")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Spacer()
                    Text("\(store.items.count)")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.quaternary)
                        .clipShape(Capsule())
                }
                .padding(.top, 20)
                .padding(.horizontal)
                
                // Search Bar (Custom Look)
                HStack {
                    Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                    TextField("Suchen...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.2)))
                .padding(.horizontal)

                // Filter Segmented Control
                Picker("", selection: $statusFilter) {
                    ForEach(StatusFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 10)
            }
            
            Divider()

            // List Area
            List(filteredItems, selection: $selection) { item in
                DocumentRowView(item: item)
                    .tag(item)
                    .listRowInsets(EdgeInsets(top: 8, leading: 10, bottom: 8, trailing: 10))
                    .listRowSeparator(.hidden)
                    .listRowBackground(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selection == item ? Color.accentColor.opacity(0.15) : Color.clear)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 4)
                    )
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
        }
    }

    // MARK: - Content Views

    private var preview: some View {
        ZStack {
            Color(nsColor: .underPageBackgroundColor)
            if let sel = selection {
                PDFKitNSView(url: sel.fileURL)
                    .id(sel.id)
                    .shadow(radius: 5)
                    .padding()
            } else {
                ContentUnavailableView("Kein Dokument ausgewählt", systemImage: "doc.text.magnifyingglass")
            }
        }
    }

    private var metadataPanel: some View {
        Group {
            if let sel = selection {
                MetadataEditorView(item: sel)
                    .id(sel.id)
            } else {
                ZStack {
                    Color(nsColor: .controlBackgroundColor)
                    Text("Wähle ein Dokument für Details")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Logic Helpers

    private var filteredItems: [DocumentItem] {
        let q = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return store.items.filter { item in
            let isAnalyzed = !item.correspondent.isEmpty
            switch statusFilter {
            case .all:      break
            case .pending:  if isAnalyzed { return false }
            case .analyzed: if !isAnalyzed { return false }
            }
            if q.isEmpty { return true }
            if item.fileName.lowercased().contains(q) { return true }
            if item.correspondent.lowercased().contains(q) { return true }
            if item.tags.contains(where: { $0.lowercased().contains(q) }) { return true }
            return false
        }
    }
    
    private func handleItemsChange(oldItems: [DocumentItem], newItems: [DocumentItem]) {
        if newItems.isEmpty {
            selection = nil
            return
        }
        if let currentSel = selection {
            if newItems.contains(where: { $0.id == currentSel.id }) {
                if let updatedItem = newItems.first(where: { $0.id == currentSel.id }) {
                    selection = updatedItem
                }
                return
            } else {
                if let oldIndex = oldItems.firstIndex(where: { $0.id == currentSel.id }) {
                    if oldIndex < newItems.count {
                        selection = newItems[oldIndex]
                    } else if !newItems.isEmpty {
                        selection = newItems.last
                    } else {
                        selection = nil
                    }
                } else {
                    selection = newItems.first
                }
            }
        } else {
            selection = newItems.first
        }
    }
}

// MARK: - Subviews

struct DocumentRowView: View {
    let item: DocumentItem
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(item.fileName)
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
                if !item.correspondent.isEmpty {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.caption)
                }
            }
            
            HStack {
                if !item.correspondent.isEmpty {
                    Text(item.correspondent)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    Text("Neu / Unbekannt")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
                
                Spacer()
                
                if let tag = item.tags.first {
                    Text(tag.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .padding(.horizontal, 4)
                        .padding(.vertical, 2)
                        .background(Color.accentColor.opacity(0.1))
                        .foregroundStyle(Color.accentColor)
                        .cornerRadius(4)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct PDFKitNSView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        pdfView.displayMode = .singlePageContinuous
        pdfView.displayDirection = .vertical
        pdfView.backgroundColor = .clear
        return pdfView
    }

    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document?.documentURL != url {
            pdfView.document = PDFDocument(url: url)
        }
    }
}
