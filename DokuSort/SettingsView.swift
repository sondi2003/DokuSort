//
//  SettingsView.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import SwiftUI

struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettingsTab()
                .tabItem {
                    Label("Allgemein", systemImage: "gear")
                }
            
            AISettingsTab()
                .tabItem {
                    Label("Intelligenz", systemImage: "brain.head.profile")
                }
            
            CatalogSettingsTab()
                .tabItem {
                    Label("Katalog", systemImage: "books.vertical")
                }
        }
        .frame(width: 600, height: 450) // Standardgröße für Settings
        .padding()
    }
}

// MARK: - Tab 1: Allgemein & Ordner
struct GeneralSettingsTab: View {
    @EnvironmentObject var settings: SettingsStore
    
    var body: some View {
        Form {
            Section {
                // Quelle
                LabeledContent("Eingang (Quelle)") {
                    HStack {
                        PathText(url: settings.sourceBaseURL)
                        Button("Wählen") { settings.chooseSourceFolder() }
                    }
                }
                
                // Ziel
                LabeledContent("Archiv (Ziel)") {
                    HStack {
                        PathText(url: settings.archiveBaseURL)
                        Button("Wählen") { settings.chooseArchiveBaseFolder() }
                    }
                }
            } header: {
                Text("Speicherorte").bold()
            }
            
            Section {
                Toggle(isOn: $settings.placeModeMove) {
                    Text("Dateien verschieben")
                    Text("Deaktivieren, um Kopien anzulegen.").font(.caption).foregroundStyle(.secondary)
                }
                
                if !settings.placeModeMove {
                    Toggle("Original nach Kopie löschen", isOn: $settings.deleteOriginalAfterCopy)
                }
                
                Picker("Bei Namenskonflikten", selection: $settings.conflictPolicyRaw) {
                    Text("Nachfragen").tag(ConflictPolicy.ask.rawValue)
                    Text("Automatisch umbenennen").tag(ConflictPolicy.autoSuffix.rawValue)
                    Text("Überschreiben").tag(ConflictPolicy.overwrite.rawValue)
                }
            } header: {
                Text("Verhalten").bold()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 2: KI & Modelle
struct AISettingsTab: View {
    @EnvironmentObject var settings: SettingsStore
    @State private var showPrompt = false
    
    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $settings.ollamaBaseURL)
                    .textFieldStyle(.roundedBorder)
                    .help("Standard: http://127.0.0.1:11434")
                
                TextField("Modell Name", text: $settings.ollamaModel)
                    .textFieldStyle(.roundedBorder)
                    .help("z.B. llama3, mistral, gemma")
            } header: {
                Text("Ollama Verbindung").bold()
            }
            
            Section {
                DisclosureGroup("System Prompt bearbeiten", isExpanded: $showPrompt) {
                    VStack(alignment: .leading) {
                        TextEditor(text: $settings.ollamaPrompt)
                            .font(.system(.caption, design: .monospaced))
                            .frame(minHeight: 150)
                            .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                        
                        Button("Auf Standard zurücksetzen") {
                            settings.resetOllamaPromptToDefault()
                        }
                        .font(.caption)
                    }
                }
            } header: {
                Text("Experten-Einstellungen").bold()
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Tab 3: Katalog (Lernspeicher)
struct CatalogSettingsTab: View {
    @EnvironmentObject var catalog: CatalogStore
    
    @State private var newKorr = ""
    @State private var newTag = ""
    
    var body: some View {
        Form {
            Section {
                HStack {
                    TextField("Neuer Eintrag...", text: $newKorr)
                        .onSubmit { addKorr() }
                    Button { addKorr() } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(newKorr.isEmpty)
                }
                
                List {
                    ForEach(catalog.correspondents, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { idx in
                        idx.forEach { catalog.deleteCorrespondent(at: $0) }
                    }
                }
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.1)))
                
                Text("\(catalog.correspondents.count) Einträge")
                    .font(.caption).foregroundStyle(.secondary)
            } header: {
                Text("Bekannte Korrespondenten").bold()
            }
            
            Section {
                HStack {
                    TextField("Neuer Typ...", text: $newTag)
                        .onSubmit { addTag() }
                    Button { addTag() } label: {
                        Image(systemName: "plus")
                    }
                    .disabled(newTag.isEmpty)
                }
                
                List {
                    ForEach(catalog.tags, id: \.self) { tag in
                        Text(tag)
                    }
                    .onDelete { idx in
                        idx.forEach { catalog.deleteTag(at: $0) }
                    }
                }
                .frame(minHeight: 120)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.gray.opacity(0.1)))
            } header: {
                Text("Dokumenttypen / Tags").bold()
            }
        }
        .formStyle(.grouped)
    }
    
    func addKorr() {
        guard !newKorr.isEmpty else { return }
        catalog.addCorrespondent(newKorr)
        newKorr = ""
    }
    
    func addTag() {
        guard !newTag.isEmpty else { return }
        catalog.addTag(newTag)
        newTag = ""
    }
}

// Kleiner Helper für Pfad-Anzeige
struct PathText: View {
    let url: URL?
    var body: some View {
        if let url {
            Text(url.path(percentEncoded: false))
                .truncationMode(.middle)
                .foregroundStyle(.secondary)
                .help(url.path)
        } else {
            Text("Nicht konfiguriert")
                .foregroundStyle(.red)
                .italic()
        }
    }
}
