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
    @State private var showPromptEditor = false
    @State private var editingKorrespondentIndex: Int? = nil
    @State private var editingKorrespondentValue = ""
    @State private var newKorrespondent = ""
    @State private var editingDokumenttypIndex: Int? = nil
    @State private var editingDokumenttypValue = ""
    @State private var newDokumenttyp = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Einstellungen").font(.title2).bold()

                GroupBox("Ordner") {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Quelle:")
                        Text(settings.sourceBaseURL?.path ?? "Kein Ordner gewählt")
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(settings.sourceBaseURL == nil ? .secondary : .primary)
                        Spacer()
                        Button { settings.chooseSourceFolder() } label: {
                            Label("Wählen", systemImage: "folder")
                        }
                    }
                    HStack {
                        Text("Ziel (Archiv-Basis):")
                        Text(settings.archiveBaseURL?.path ?? "Kein Ordner gewählt")
                            .lineLimit(1).truncationMode(.middle)
                            .foregroundStyle(settings.archiveBaseURL == nil ? .secondary : .primary)
                        Spacer()
                        Button { settings.chooseArchiveBaseFolder() } label: {
                            Label("Wählen", systemImage: "folder.badge.plus")
                        }
                    }
                }.padding(8)
            }

            GroupBox("Ablageverhalten") {
                VStack(alignment: .leading, spacing: 8) {
                    Toggle(isOn: $settings.placeModeMove) { Text("Verschieben (empfohlen)") }
                    Text("Wenn deaktiviert, wird kopiert.").font(.caption).foregroundStyle(.secondary)

                    Toggle(isOn: $settings.deleteOriginalAfterCopy) { Text("Nach dem Kopieren Original löschen") }
                        .disabled(settings.placeModeMove)
                    Text("Nur wirksam, wenn Kopieren aktiv ist.").font(.caption).foregroundStyle(.secondary)

                    Divider()
                    Text("Konflikte bei bestehendem Dateinamen")
                    Picker("", selection: $settings.conflictPolicyRaw) {
                        Text("Fragen").tag(ConflictPolicy.ask.rawValue)
                        Text("Automatisch suffixen").tag(ConflictPolicy.autoSuffix.rawValue)
                        Text("Überschreiben").tag(ConflictPolicy.overwrite.rawValue)
                    }
                    .pickerStyle(.segmented)
                }.padding(8)
            }

            GroupBox("Ollama (optional)") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Base URL")
                        TextField("http://127.0.0.1:11434", text: $settings.ollamaBaseURL)
                            .textFieldStyle(.roundedBorder)
                    }
                    HStack {
                        Text("Modell")
                        TextField("llama3.1", text: $settings.ollamaModel)
                            .textFieldStyle(.roundedBorder)
                    }

                    Divider()

                    DisclosureGroup(isExpanded: $showPromptEditor) {
                        VStack(alignment: .leading, spacing: 8) {
                            TextEditor(text: $settings.ollamaPrompt)
                                .font(.system(.body, design: .monospaced))
                                .frame(minHeight: 200)
                                .border(Color.gray.opacity(0.3))

                            HStack {
                                Button("Auf Standard zurücksetzen") {
                                    settings.resetOllamaPromptToDefault()
                                }
                                Spacer()
                            }

                            Text("Verwende {TEXT} als Platzhalter für den analysierten Text.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } label: {
                        Text("System Prompt anpassen")
                            .font(.headline)
                    }

                    Text("Ollama lokal starten (`ollama serve`) und Modell installiert haben.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }

            GroupBox("Korrespondenten verwalten") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Neuer Korrespondent", text: $newKorrespondent)
                            .textFieldStyle(.roundedBorder)
                        Button("Hinzufügen") {
                            catalog.addKorrespondent(newKorrespondent)
                            newKorrespondent = ""
                        }
                        .disabled(newKorrespondent.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Divider()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(catalog.korrespondenten.enumerated()), id: \.offset) { index, korr in
                                HStack {
                                    if editingKorrespondentIndex == index {
                                        TextField("", text: $editingKorrespondentValue)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Speichern") {
                                            catalog.editKorrespondent(at: index, newValue: editingKorrespondentValue)
                                            editingKorrespondentIndex = nil
                                        }
                                        Button("Abbrechen") {
                                            editingKorrespondentIndex = nil
                                        }
                                    } else {
                                        Text(korr)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Button(action: {
                                            editingKorrespondentIndex = index
                                            editingKorrespondentValue = korr
                                        }) {
                                            Image(systemName: "pencil")
                                        }
                                        Button(action: {
                                            catalog.deleteKorrespondent(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                        }
                                        .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.3))

                    Text("\(catalog.korrespondenten.count) Korrespondent(en) gespeichert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }.padding(8)
            }

            GroupBox("Dokumenttypen verwalten") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        TextField("Neuer Dokumenttyp", text: $newDokumenttyp)
                            .textFieldStyle(.roundedBorder)
                        Button("Hinzufügen") {
                            catalog.addDokumenttyp(newDokumenttyp)
                            newDokumenttyp = ""
                        }
                        .disabled(newDokumenttyp.trimmingCharacters(in: .whitespaces).isEmpty)
                    }

                    Divider()

                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(Array(catalog.dokumenttypen.enumerated()), id: \.offset) { index, typ in
                                HStack {
                                    if editingDokumenttypIndex == index {
                                        TextField("", text: $editingDokumenttypValue)
                                            .textFieldStyle(.roundedBorder)
                                        Button("Speichern") {
                                            catalog.editDokumenttyp(at: index, newValue: editingDokumenttypValue)
                                            editingDokumenttypIndex = nil
                                        }
                                        Button("Abbrechen") {
                                            editingDokumenttypIndex = nil
                                        }
                                    } else {
                                        Text(typ)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Button(action: {
                                            editingDokumenttypIndex = index
                                            editingDokumenttypValue = typ
                                        }) {
                                            Image(systemName: "pencil")
                                        }
                                        Button(action: {
                                            catalog.deleteDokumenttyp(at: index)
                                        }) {
                                            Image(systemName: "trash")
                                        }
                                        .foregroundColor(.red)
                                    }
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                    .frame(height: 150)
                    .border(Color.gray.opacity(0.3))

                    Text("\(catalog.dokumenttypen.count) Dokumenttyp(en) gespeichert")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }.padding(8)
            }

                HStack {
                    Spacer()
                    Button("Schliessen") { dismiss() }
                        .keyboardShortcut(.cancelAction)
                }
            }
            .padding(20)
        }
        .frame(minWidth: 640, minHeight: 500)
    }
}
