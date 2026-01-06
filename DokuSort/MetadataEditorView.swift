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
    
    // Lokaler State
    @State private var datum: Date = Date()
    @State private var korrespondent: String = ""
    @State private var tags: String = ""
    @State private var extractedText: String = ""
    
    // UI Logic
    @State private var isAnalyzing: Bool = false
    @State private var showOriginalPDF: Bool = false
    @State private var statusMessage: String? = nil
    
    private let analysisService = DocumentAnalysisService()
    
    var body: some View {
        Form {
            Section(header: Text("Analyse & Vorschläge")) {
                HStack {
                    if isAnalyzing {
                        ProgressView().scaleEffect(0.5)
                        Text("Analysiere...").font(.caption).foregroundColor(.secondary)
                    } else {
                        Button(action: {
                            // MANUELLER KLICK: Erzwinge frische OCR (ignoriere alten Text im PDF)
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
                TextField("Tags (kommagetrennt)", text: $tags)
            }
            
            Section(header: Text("Extrahierter Text (Basis für KI)")) {
                TextEditor(text: $extractedText)
                    .frame(height: 150)
                    .font(.custom("Menlo", size: 10))
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
            }
            
            Section {
                Button("Speichern") { saveChanges() }
                .keyboardShortcut(.defaultAction)
                
                Button("Original anzeigen") { showOriginalPDF = true }
            }
        }
        .padding()
        .onAppear { loadInitialData() }
        .sheet(isPresented: $showOriginalPDF) {
            PDFPreviewScreen(item: item.fileURL)
        }
        .task(id: item.id) {
            // AUTOMATISCH: Nur analysieren, wenn noch nichts da ist.
            // Schnellmodus (forceOCR: false), um nicht jedes Mal zu warten.
            if item.extractedText == nil || item.extractedText?.isEmpty == true {
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
        // Status zurücksetzen bei neuem Item
        self.statusMessage = nil
    }
    
    private func saveChanges() {
        let tagArray = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
        
        let updated = DocumentItem(
            id: item.id,
            fileName: item.fileName,
            fileURL: item.fileURL,
            fileSize: item.fileSize,
            addedAt: item.addedAt,
            date: datum,
            correspondent: korrespondent,
            tags: tagArray,
            extractedText: extractedText
        )
        
        store.update(updated)
    }
    
    private func runSmartAnalysis(forceOCR: Bool) async {
        isAnalyzing = true
        statusMessage = forceOCR ? "Scanne Bild & analysiere..." : "Analysiere..."
        
        let config = AnalysisConfig(
            ollamaBaseURL: settings.ollamaBaseURL,
            ollamaModel: settings.ollamaModel,
            ollamaPrompt: settings.ollamaPrompt
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
            }
        } catch {
            await MainActor.run {
                self.statusMessage = "Fehler: \(error.localizedDescription)"
                self.isAnalyzing = false
            }
        }
    }
}
