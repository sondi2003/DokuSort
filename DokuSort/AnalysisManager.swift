//
//  AnalysisManager.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine

/// Verwalten der Analyse-States inkl. Persistenz.
@MainActor
final class AnalysisManager: ObservableObject {

    // Eigener Publisher, da wir manuell `objectWillChange.send()` ausloesen.
    let objectWillChange = ObservableObjectPublisher()

    private let persistence = PersistedStateStore.shared
    private var cache: [String: AnalysisState] = [:] // Key = fileURL.path

    init() {
        persistence.loadFromDisk()
        self.cache = [:]
    }

    // UI: Zaehler/Progress
    var analyzedCount: Int {
        cache.values.filter { $0.status == .analyzed }.count
    }

    func progress(total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(analyzedCount) / Double(total)
    }

    // MARK: Query

    func state(for url: URL) -> AnalysisState? {
        if let s = cache[url.path] {
            return s
        }
        if let s = persistence.state(for: url),
           isStateValid(s, for: url) {
            cache[url.path] = s
            return s
        }
        return nil
    }

    func isAnalyzed(_ url: URL) -> Bool {
        if let s = state(for: url) { return s.status == .analyzed }
        return false
    }

    // MARK: Mutation

    func markAnalyzed(url: URL, state: AnalysisState) {
        guard isStateValid(state, for: url) else { return }
        cache[url.path] = state
        persistence.upsert(url: url, state: state)
        objectWillChange.send()
    }

    func markFailed(url: URL) {
        let s = AnalysisState(status: .failed,
                              confidence: 0,
                              korrespondent: nil,
                              dokumenttyp: nil,
                              datum: nil,
                              fileSize: (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map(Int64.init),
                              fileModDate: (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate))
        cache[url.path] = s
        persistence.upsert(url: url, state: s)
        objectWillChange.send()
    }

    func remove(url: URL) {
        cache.removeValue(forKey: url.path)
        persistence.remove(url: url)
        objectWillChange.send()
    }

    func reset() {
        cache.removeAll()
        persistence.cleanupMissingFiles()
        objectWillChange.send()
    }

    // MARK: Helpers

    private func isStateValid(_ s: AnalysisState, for url: URL) -> Bool {
        guard let sizeSaved = s.fileSize, let modSaved = s.fileModDate else { return true }
        let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        let sizeNow = values?.fileSize.map(Int64.init)
        let modNow  = values?.contentModificationDate
        return sizeSaved == sizeNow && modSaved == modNow
    }
}
