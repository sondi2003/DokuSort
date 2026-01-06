//
//  AppSettingsSheet.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

struct AppSettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @EnvironmentObject private var catalog: CatalogStore
    @Environment(\.dismiss) private var dismiss
    
    // Lokaler State für Eingabefelder
    @State private var newKorrespondent = ""
    @State private var newDokumenttyp = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Einstellungen").font(.title2).bold()

                // MARK: - Ordner Einstellungen
                GroupBox("Ordner Pfade") {
                    VStack(alignment: .leading, spacing: 12) {
                        // Quelle
                        HStack {
                            Label("Eingang (Quelle):", systemImage: "tray.and.arrow.down")
                            Spacer()
                            if let url = settings.sourceBaseURL {
                                Text(url.lastPathComponent).foregroundStyle(.secondary)
                            } else {
                                Text("Nicht gewählt").foregroundStyle(.red)
                            }
                            Button("Wählen") { settings.chooseSourceFolder() }
                        }
                        
                        Divider()
                        
                        // Ziel (Archiv)
                        HStack {
                            Label("Archiv (Ziel):", systemImage: "archivebox")
                            Spacer()
                            if let url = settings.archiveBaseURL {
                                Text(url.lastPathComponent).foregroundStyle(.secondary)
                            } else {
                                Text("Nicht gewählt").foregroundStyle(.red)
                            }
                            // KORREKTUR: Hier hieß es fälschlicherweise chooseArchiveFolder
                            Button("Wählen") { settings.chooseArchiveBaseFolder() }
                        }
                    }
                    .padding(8)
                }
                
                // MARK: - KI Einstellungen
                GroupBox("KI Konfiguration (Ollama)") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Ollama URL", text: $settings.ollamaBaseURL)
                            .textFieldStyle(.roundedBorder)
                        
                        TextField("Modell Name", text: $settings.ollamaModel)
                            .textFieldStyle(.roundedBorder)
                        
                        Text("Prompt Template:")
                            .font(.caption)
                        TextEditor(text: $settings.ollamaPrompt)
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.2))
                    }
                    .padding(8)
                }
                
                // MARK: - Katalog Management
                GroupBox("Katalog & Lernspeicher") {
                    VStack(alignment: .leading, spacing: 16) {
                        
                        // 1. Korrespondenten
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bekannte Korrespondenten").font(.headline)
                            HStack {
                                TextField("Neuer Korrespondent", text: $newKorrespondent)
                                    .onSubmit { addKorr() }
                                Button(action: addKorr) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .disabled(newKorrespondent.isEmpty)
                            }
                            
                            List {
                                ForEach(catalog.correspondents, id: \.self) { name in
                                    Text(name)
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { catalog.deleteCorrespondent(at: $0) }
                                }
                            }
                            .frame(height: 150)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                        }
                        
                        // 2. Dokumenttypen (Tags)
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Bekannte Dokumenttypen (Tags)").font(.headline)
                            HStack {
                                TextField("Neuer Typ", text: $newDokumenttyp)
                                    .onSubmit { addType() }
                                Button(action: addType) {
                                    Image(systemName: "plus.circle.fill")
                                }
                                .disabled(newDokumenttyp.isEmpty)
                            }
                            
                            List {
                                ForEach(catalog.tags, id: \.self) { tag in
                                    Text(tag)
                                }
                                .onDelete { indexSet in
                                    indexSet.forEach { catalog.deleteTag(at: $0) }
                                }
                            }
                            .frame(height: 150)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.2)))
                        }
                    }
                    .padding(8)
                }

                HStack {
                    Spacer()
                    Button("Schliessen") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 500, minHeight: 600)
    }
    
    // MARK: - Helpers
    
    private func addKorr() {
        guard !newKorrespondent.isEmpty else { return }
        catalog.addCorrespondent(newKorrespondent)
        newKorrespondent = ""
    }
    
    private func addType() {
        guard !newDokumenttyp.isEmpty else { return }
        catalog.addTag(newDokumenttyp)
        newDokumenttyp = ""
    }
}
