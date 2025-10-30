//
//  AnalysisManager.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine

/// Verwalten der Analyse-States inkl. Persistenz in JSON.
/// - Hoert auf Notifications aus UI/Background:
///   - .analysisDidFinish  (userInfo["state"] = AnalysisState)
///   - .documentDidArchive (loescht Cache-Eintrag)
@MainActor
final class AnalysisManager: ObservableObject {

    // Eigenen Publisher verwenden, da wir manuell Aenderungen signalisieren
    let objectWillChange = ObservableObjectPublisher()

    private let persistence = PersistedStateStore.shared
    /// In-Memory-Cache (Key = normalized file path)
    private var cache: [String: AnalysisState] = [:]

    private var observers: [AnyCancellable] = []

    // MARK: Init

    init() {
        // Persistenz laden und lazy bei Bedarf verwenden
        persistence.loadFromDisk()
        setupObservers()
        print("📂 [AnalysisManager] init – Persistenz geladen")
    }

    // MARK: Public: UI-Helfer

    var analyzedCount: Int {
        cache.values.filter { $0.status == .analyzed }.count
    }

    func progress(total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(analyzedCount) / Double(total)
    }

    // MARK: Public: Query

    /// Liefert State aus Cache oder Persistenz (falls gueltig).
    func state(for url: URL) -> AnalysisState? {
        let canonicalURL = url.normalizedFileURL
        let key = key(for: canonicalURL)
        if let s = cache[key] {
            print("✅ [AnalysisManager] Cache-Hit: \(canonicalURL.lastPathComponent)")
            return s
        }
        if let s = persistence.state(for: canonicalURL), isStateValid(s, for: canonicalURL) {
            cache[key] = s
            print("📦 [AnalysisManager] Persistenz-Hit: \(canonicalURL.lastPathComponent)")
            return s
        }
        print("⚠️ [AnalysisManager] Kein State gefunden: \(canonicalURL.lastPathComponent)")
        return nil
    }

    func isAnalyzed(_ url: URL) -> Bool {
        let canonicalURL = url.normalizedFileURL
        if let s = state(for: canonicalURL) { return s.status == .analyzed }
        return false
    }

    // MARK: Public: Mutation API (direkte Aufrufer wie BackgroundAnalyzer)

    func markAnalyzed(url: URL, state: AnalysisState) {
        let canonicalURL = url.normalizedFileURL
        guard isStateValid(state, for: canonicalURL) else {
            print("⚠️ [AnalysisManager] markAnalyzed verworfen (ungueltig): \(canonicalURL.lastPathComponent)")
            return
        }
        let key = key(for: canonicalURL)
        cache[key] = state
        persistence.upsert(url: canonicalURL, state: state)
        objectWillChange.send()
        print("📥 [AnalysisManager] markAnalyzed gespeichert: \(canonicalURL.lastPathComponent)")
    }

    func markFailed(url: URL) {
        let canonicalURL = url.normalizedFileURL
        let values = try? canonicalURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let s = AnalysisState(
            status: .failed,
            confidence: 0,
            korrespondent: nil,
            dokumenttyp: nil,
            datum: nil,
            fileSize: values?.fileSize.map(Int64.init),
            fileModDate: values?.contentModificationDate
        )
        let key = key(for: canonicalURL)
        cache[key] = s
        persistence.upsert(url: canonicalURL, state: s)
        objectWillChange.send()
        print("❌ [AnalysisManager] markFailed gespeichert: \(canonicalURL.lastPathComponent)")
    }

    func remove(url: URL) {
        let canonicalURL = url.normalizedFileURL
        let key = key(for: canonicalURL)
        cache.removeValue(forKey: key)
        persistence.remove(url: canonicalURL)
        objectWillChange.send()
        print("🧹 [AnalysisManager] remove: \(canonicalURL.lastPathComponent)")
    }

    func reset() {
        cache.removeAll()
        persistence.cleanupMissingFiles()
        objectWillChange.send()
        print("🔁 [AnalysisManager] reset + cleanupMissingFiles")
    }

    // MARK: Notifications bridging (wichtig, damit View-Posts in die Persistenz kommen)

    private func setupObservers() {
        NotificationCenter.default.publisher(for: .analysisDidFinish)
            .sink { [weak self] note in
                guard let self else { return }
                guard let url = note.object as? URL else { return }
                // bevorzugt den mitgelieferten State verwenden
                if let s = note.userInfo?["state"] as? AnalysisState {
                    self.markAnalyzed(url: url, state: s)
                } else {
                    // Falls kein State mitkommt: minimaler State aus Dateifacts (failsafe)
                    let canonicalURL = url.normalizedFileURL
                    let values = try? canonicalURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
                    let s = AnalysisState(
                        status: .analyzed,
                        confidence: 0,
                        korrespondent: nil,
                        dokumenttyp: nil,
                        datum: nil,
                        fileSize: values?.fileSize.map(Int64.init),
                        fileModDate: values?.contentModificationDate
                    )
                    self.markAnalyzed(url: canonicalURL, state: s)
                }
            }
            .store(in: &observers)

        NotificationCenter.default.publisher(for: .documentDidArchive)
            .sink { [weak self] note in
                guard let self, let url = note.object as? URL else { return }
                self.remove(url: url)
            }
            .store(in: &observers)
    }

    // MARK: Helpers

    /// Prueft, ob gespeicherte Facts (Groesse + mtime) noch zur aktuellen Datei passen.
    private func isStateValid(_ s: AnalysisState, for url: URL) -> Bool {
        guard let sizeSaved = s.fileSize, let modSaved = s.fileModDate else { return true }
        let canonicalURL = url.normalizedFileURL
        let values = try? canonicalURL.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let sizeNow = values?.fileSize.map(Int64.init)
        let modNow  = values?.contentModificationDate
        let ok = (sizeSaved == sizeNow && modSaved == modNow)
        if !ok {
            print("⚠️ [AnalysisManager] State ungueltig (Datei geaendert): \(canonicalURL.lastPathComponent)")
        }
        return ok
    }

    private func key(for url: URL) -> String {
        url.normalizedFilePath
    }
}
