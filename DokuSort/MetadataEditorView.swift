//
//  MetadataEditorView.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import SwiftUI
import PDFKit

struct MetadataEditorView: View {
    let item: DocumentItem
    
    @EnvironmentObject var store: DocumentStore
    @EnvironmentObject var settings: SettingsStore
    
    @State private var datum: Date = Date()
    @State private var korrespondent: String = ""
    @State private var tags: String = ""
    @State private var extractedText: String = ""
    
    @State private var isAnalyzing: Bool = false
    @State private var showOriginalPDF: Bool = false
    @State private var statusMessage: String? = nil
    
    private let analysisService = DocumentAnalysisService()
    
    private var previewFilename: String {
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        let tempItem = DocumentItem(
            id: item.id, fileName: "", fileURL: item.fileURL, fileSize: 0, addedAt: Date(),
            date: datum, correspondent: korrespondent, tags: tagArray, extractedText: ""
        )
        return ArchiveService.generateFilename(for: tempItem)
    }
    
    var body: some View {
        Form {
            Section(header: Text("Analyse & Vorschläge")) {
                HStack {
                    if isAnalyzing {
                        ProgressView().scaleEffect(0.5)
                        Text("Analysiere...").font(.caption).foregroundColor(.secondary)
                    } else {
                        Button(action: {
                            Task { await runSmartAnalysis(forceOCR: true) }
                        }) {
                            Label("Neu analysieren (Zauberstab)", systemImage: "wand.and.stars")
                        }
                        .disabled(isAnalyzing)
                        
                        if let msg = statusMessage {
                            Text(msg).font(.caption).foregroundColor(.secondary)
                        }
                    }
                }
            }
            
            Section(header: Text("Metadaten")) {
                DatePicker("Datum", selection: $datum, displayedComponents: .date)
                TextField("Korrespondent", text: $korrespondent)
                TextField("Tags / Typ", text: $tags)
                
                if !korrespondent.isEmpty {
                    LabeledContent("Vorschau Dateiname", value: previewFilename)
                        .font(.caption).foregroundColor(.secondary)
                }
            }
            
            Section(header: Text("Extrahierter Text (im PDF gespeichert)")) {
                TextEditor(text: $extractedText)
                    .frame(height: 100)
                    .font(.custom("Menlo", size: 10))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
            }
            
            Section {
                HStack {
                    Button("Nur Speichern") { saveChanges(archive: false) }
                    Spacer()
                    Button { saveChanges(archive: true) } label: {
                        Label("Archivieren", systemImage: "tray.and.arrow.down.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(korrespondent.isEmpty || settings.archiveBaseURL == nil)
                }
                
                if settings.archiveBaseURL == nil {
                    Text("⚠️ Kein Zielordner gewählt").font(.caption).foregroundColor(.red)
                }
                Button("Original anzeigen") { showOriginalPDF = true }
            }
        }
        .padding()
        .onAppear { loadInitialData() }
        .sheet(isPresented: $showOriginalPDF) {
            PDFPreviewScreen(item: item.fileURL)
        }
        .task(id: item.id) {
            // Nur analysieren wenn noch keine Metadaten im PDF waren
            let hasMetadata = !item.correspondent.isEmpty || (item.extractedText?.count ?? 0) > 50
            if !hasMetadata {
                 await runSmartAnalysis(forceOCR: false)
            }
        }
    }
    
    // MARK: - Logic
    
    private func loadInitialData() {
        self.datum = item.date
        self.korrespondent = item.correspondent
        self.tags = item.tags.joined(separator: ", ")
        self.extractedText = item.extractedText ?? ""
        self.statusMessage = nil
    }
    
    private func saveChanges(archive: Bool) {
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let updatedItem = DocumentItem(
            id: item.id, fileName: item.fileName, fileURL: item.fileURL, fileSize: item.fileSize, addedAt: item.addedAt,
            date: datum, correspondent: korrespondent, tags: tagArray, extractedText: extractedText
        )
        
        if archive {
            // Erst speichern (ins PDF schreiben), dann verschieben
            store.update(updatedItem)
            performArchiving(item: updatedItem)
        } else {
            store.update(updatedItem)
        }
    }
    
    private func performArchiving(item: DocumentItem) {
        guard let dest = settings.archiveBaseURL else {
            statusMessage = "Fehler: Kein Zielordner konfiguriert."
            return
        }
        
        let accessing = dest.startAccessingSecurityScopedResource()
        defer { if accessing { dest.stopAccessingSecurityScopedResource() } }
        
        do {
            _ = try ArchiveService.archive(item: item, destinationFolder: dest)
            store.delete(item)
            #if os(macOS)
            NSSound(named: "Glass")?.play()
            #endif
        } catch {
            statusMessage = "Fehler: \(error.localizedDescription)"
        }
    }
    
    private func runSmartAnalysis(forceOCR: Bool) async {
        isAnalyzing = true
        statusMessage = forceOCR ? "Tiefen-Scan..." : "Analysiere..."
        
        // NEU: Wir holen uns die Liste der bekannten Firmen
        let knownCorps = CatalogStore.shared.correspondents
        
        let config = AnalysisConfig(
            ollamaBaseURL: settings.ollamaBaseURL,
            ollamaModel: settings.ollamaModel,
            ollamaPrompt: settings.ollamaPrompt,
            knownCorrespondents: knownCorps // <--- Hier übergeben
        )
        
        do {
            let result = try await analysisService.analyze(item: item, config: config, forceOCR: forceOCR)
            
            await MainActor.run {
                self.extractedText = result.text
                if let newDate = result.suggestion.datum { self.datum = newDate }
                if let newKorr = result.suggestion.korrespondent { self.korrespondent = newKorr }
                if let type = result.suggestion.dokumenttyp { self.tags = type }
                self.statusMessage = "Fertig (\(result.source))"
                self.isAnalyzing = false
                
                // Sofort speichern ins PDF
                let autoSavedItem = DocumentItem(
                    id: item.id, fileName: item.fileName, fileURL: item.fileURL, fileSize: item.fileSize, addedAt: item.addedAt,
                    date: self.datum, correspondent: self.korrespondent, tags: self.tags.split(separator: ",").map{String($0)}, extractedText: self.extractedText
                )
                store.update(autoSavedItem)
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Fehler: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }
}
