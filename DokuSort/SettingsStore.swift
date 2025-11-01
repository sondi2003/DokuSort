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
    @Published var ollamaPrompt: String {
        didSet { UserDefaults.standard.set(ollamaPrompt, forKey: ollamaPromptKey) }
    }

    // Keys
    private let sourceBookmarkKey = "SettingsStore.sourceBaseBookmark"
    private let archiveBookmarkKey = "SettingsStore.archiveBaseBookmark"
    private let placeModeKey = "SettingsStore.placeModeMove"
    private let deleteAfterCopyKey = "SettingsStore.deleteAfterCopy"
    private let conflictPolicyKey = "SettingsStore.conflictPolicy"
    private let ollamaURLKey = "SettingsStore.ollamaBaseURL"
    private let ollamaModelKey = "SettingsStore.ollamaModel"
    private let ollamaPromptKey = "SettingsStore.ollamaPrompt"

    init() {
        self.placeModeMove = UserDefaults.standard.object(forKey: placeModeKey) as? Bool ?? true
        self.deleteOriginalAfterCopy = UserDefaults.standard.object(forKey: deleteAfterCopyKey) as? Bool ?? false
        self.conflictPolicyRaw = UserDefaults.standard.string(forKey: conflictPolicyKey) ?? ConflictPolicy.ask.rawValue
        self.ollamaBaseURL = UserDefaults.standard.string(forKey: ollamaURLKey) ?? "http://127.0.0.1:11434"
        self.ollamaModel = UserDefaults.standard.string(forKey: ollamaModelKey) ?? "llama3.1"
        self.ollamaPrompt = UserDefaults.standard.string(forKey: ollamaPromptKey) ?? Self.defaultOllamaPrompt
        restoreBookmarks()
    }

    // MARK: Default Ollama Prompt

    static let defaultOllamaPrompt = """
Du bist ein Experte für Dokumenten-Analyse. Deine Aufgabe ist es, aus deutschen Dokumenten folgende Informationen zu extrahieren:

1. **datum**: Das Rechnungs-/Dokumentdatum (Format: YYYY-MM-DD). Suche nach dem HAUPTDATUM des Dokuments, nicht nach Fälligkeits- oder Lieferdaten.

2. **korrespondent**: Der Name der Firma oder Organisation, die das Dokument ausgestellt hat (NICHT der Empfänger).
   - Bevorzuge die offizielle Firmenbezeichnung (z.B. "Swisscom AG" statt nur "Swisscom")
   - Ignoriere Abteilungsnamen oder Ansprechpersonen
   - Maximal 50 Zeichen
   - Keine Adresszeilen

3. **dokumenttyp**: Die Art des Dokuments. Wähle aus:
   - "Rechnung" (für Rechnungen, Invoices)
   - "Mahnung" (für Zahlungserinnerungen)
   - "Gutschrift" (für Credits)
   - "Offerte" (für Angebote, Quotes)
   - "Police" (für Versicherungspolizzen)
   - "Vertrag" (für Verträge, Contracts)
   - "Lieferschein" (für Delivery Notes)
   - "Dokument" (falls nichts passt)

**WICHTIG**:
- Der Korrespondent ist der ABSENDER/AUSSTELLER, nicht der Empfänger
- Bei mehreren möglichen Namen: Wähle den, der am Anfang des Dokuments steht
- Wenn unsicher: Bevorzuge kürzere, klarere Namen

**Beispiele:**

Beispiel 1 - Rechnung:
Input: "Swisscom AG\\nHardturmstrasse 3\\n8005 Zürich\\n\\nRechnung Nr. 2024-1234\\nDatum: 15.03.2024\\n\\nAn: Max Mustermann..."
Output: {"datum": "2024-03-15", "korrespondent": "Swisscom AG", "dokumenttyp": "Rechnung"}

Beispiel 2 - Versicherung:
Input: "AXA Versicherungen\\nGeneraldirektion\\n\\nVersicherungspolice Nr. 123456\\nGültig ab: 01.01.2024..."
Output: {"datum": "2024-01-01", "korrespondent": "AXA Versicherungen", "dokumenttyp": "Police"}

Beispiel 3 - Offerte:
Input: "ACME GmbH\\nOffertnummer: OFF-2024-089\\nDatum: 20.02.2024\\n\\nSehr geehrter Herr..."
Output: {"datum": "2024-02-24", "korrespondent": "ACME GmbH", "dokumenttyp": "Offerte"}

**Antworte NUR mit dem JSON-Objekt. Keine Erklärungen, kein Fließtext, keine Code-Blöcke.**

Zu analysierender Text:
{TEXT}
"""

    // MARK: Ollama Prompt

    func resetOllamaPromptToDefault() {
        ollamaPrompt = Self.defaultOllamaPrompt
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
            let normalized = url.normalizedFileURL
            saveBookmark(for: url, key: sourceBookmarkKey)
            _ = url.startAccessingSecurityScopedResource()
            sourceBaseURL = normalized
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
            let normalized = url.normalizedFileURL
            saveBookmark(for: url, key: archiveBookmarkKey)
            _ = url.startAccessingSecurityScopedResource()
            archiveBaseURL = normalized
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
                return url.normalizedFileURL
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
