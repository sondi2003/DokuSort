//
//  SettingsStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine
import AppKit

@MainActor
final class SettingsStore: ObservableObject {
    // Quelle und Ziel (Security-Scoped)
    @Published private(set) var sourceBaseURL: URL?
    @Published private(set) var archiveBaseURL: URL?

    // Ablage-Optionen
    @Published var placeModeMove: Bool {
        didSet { UserDefaults.standard.set(placeModeMove, forKey: placeModeKey) }
    }
    @Published var deleteOriginalAfterCopy: Bool {
        didSet { UserDefaults.standard.set(deleteOriginalAfterCopy, forKey: deleteAfterCopyKey) }
    }
    @Published var conflictPolicyRaw: String {
        didSet { UserDefaults.standard.set(conflictPolicyRaw, forKey: conflictPolicyKey) }
    }
    var conflictPolicy: ConflictPolicy {
        ConflictPolicy(rawValue: conflictPolicyRaw) ?? .ask
    }

    // Ollama
    @Published var ollamaBaseURL: String {
        didSet { UserDefaults.standard.set(ollamaBaseURL, forKey: ollamaURLKey) }
    }
    @Published var ollamaModel: String {
        didSet { UserDefaults.standard.set(ollamaModel, forKey: ollamaModelKey) }
    }

    // Keys
    private let sourceBookmarkKey = "SettingsStore.sourceBaseBookmark"
    private let archiveBookmarkKey = "SettingsStore.archiveBaseBookmark"
    private let placeModeKey = "SettingsStore.placeModeMove"
    private let deleteAfterCopyKey = "SettingsStore.deleteAfterCopy"
    private let conflictPolicyKey = "SettingsStore.conflictPolicy"
    private let ollamaURLKey = "SettingsStore.ollamaBaseURL"
    private let ollamaModelKey = "SettingsStore.ollamaModel"

    init() {
        self.placeModeMove = UserDefaults.standard.object(forKey: placeModeKey) as? Bool ?? true
        self.deleteOriginalAfterCopy = UserDefaults.standard.object(forKey: deleteAfterCopyKey) as? Bool ?? false
        self.conflictPolicyRaw = UserDefaults.standard.string(forKey: conflictPolicyKey) ?? ConflictPolicy.ask.rawValue
        self.ollamaBaseURL = UserDefaults.standard.string(forKey: ollamaURLKey) ?? "http://127.0.0.1:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: ollamaModelKey) ?? "llama3.1"
        restoreBookmarks()
    }

    // MARK: Auswahl-Dialoge

    func chooseSourceFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false               // << Nur Ordner
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Quelle wählen"
        panel.message = "Wähle den Quellordner, aus dem PDFs geladen werden."
        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url, key: sourceBookmarkKey)
            _ = url.startAccessingSecurityScopedResource()
            sourceBaseURL = url
        }
    }

    func chooseArchiveBaseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false               // << Nur Ordner
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Ziel wählen"
        panel.message = "Wähle den Basisordner für die Ablage."
        if panel.runModal() == .OK, let url = panel.url {
            saveBookmark(for: url, key: archiveBookmarkKey)
            _ = url.startAccessingSecurityScopedResource()
            archiveBaseURL = url
        }
    }

    // MARK: Bookmarks

    private func saveBookmark(for url: URL, key: String) {
        do {
            let data = try url.bookmarkData(options: .withSecurityScope,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil)
            UserDefaults.standard.set(data, forKey: key)
        } catch {
            print("Bookmark speichern fehlgeschlagen (\(key)): \(error)")
        }
    }

    private func restoreBookmarks() {
        func restore(key: String) -> URL? {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            var isStale = false
            do {
                let url = try URL(resolvingBookmarkData: data,
                                  options: [.withSecurityScope],
                                  relativeTo: nil,
                                  bookmarkDataIsStale: &isStale)
                if isStale { saveBookmark(for: url, key: key) }
                _ = url.startAccessingSecurityScopedResource()
                return url
            } catch {
                print("Bookmark wiederherstellen fehlgeschlagen (\(key)): \(error)")
                return nil
            }
        }
        self.sourceBaseURL = restore(key: sourceBookmarkKey)
        self.archiveBaseURL = restore(key: archiveBookmarkKey)
    }

    // Hilfsfunktion für Ablage
    func currentPlaceMode() -> PlaceMode {
        placeModeMove ? .move : .copy(deleteOriginalAfterCopy: deleteOriginalAfterCopy)
    }
}
