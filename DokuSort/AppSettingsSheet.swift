//
//  AppSettingsSheet.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

struct AppSettingsSheet: View {
    @EnvironmentObject private var settings: SettingsStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
                    Text("Ollama lokal starten (`ollama serve`) und Modell installiert haben.")
                        .font(.caption).foregroundStyle(.secondary)
                }.padding(8)
            }

            HStack {
                Spacer()
                Button("Schliessen") { dismiss() }
                    .keyboardShortcut(.cancelAction)
            }
        }
        .padding(20)
        .frame(minWidth: 640)
    }
}
