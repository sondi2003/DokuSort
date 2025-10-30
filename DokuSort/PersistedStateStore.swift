//
//  PersistedStateStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

/// Pflegt eine kleine JSON-Datei mit Analysezuständen.
final class PersistedStateStore {
    static let shared = PersistedStateStore()

    private let queue = DispatchQueue(label: "DokuSort.PersistedStateStore", qos: .utility)
    private var states: [String: AnalysisState] = [:] // Key = normalized file path

    private var fileURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("DokuSort", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("state.json")
    }

    // MARK: Load/Save

    func loadFromDisk() {
        queue.sync {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                states = [:]; return
            }
            do {
                let data = try Data(contentsOf: fileURL)
                let decoded = try JSONDecoder().decode([String: AnalysisState].self, from: data)
                var normalized: [String: AnalysisState] = [:]
                normalized.reserveCapacity(decoded.count)
                var changed = false
                for (rawKey, value) in decoded {
                    let normalizedKey = URL(fileURLWithPath: rawKey).normalizedFilePath
                    if normalizedKey != rawKey { changed = true }
                    normalized[normalizedKey] = value
                }
                states = normalized
                if changed { saveToDisk() }
            } catch {
                // Wenn defekt: neu beginnen
                states = [:]
            }
        }
    }

    private func saveToDisk() {
        queue.async {
            do {
                let data = try JSONEncoder().encode(self.states)
                try data.write(to: self.fileURL, options: [.atomic])
            } catch {
                NSLog("PersistedStateStore: save failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: Get/Set

    func state(for url: URL) -> AnalysisState? {
        queue.sync { states[key(for: url)] }
    }

    func upsert(url: URL, state: AnalysisState) {
        queue.sync {
            states[key(for: url)] = state
        }
        saveToDisk()
    }

    func remove(url: URL) {
        queue.sync {
            states.removeValue(forKey: key(for: url))
        }
        saveToDisk()
    }

    /// Entfernt Einträge, deren Dateien nicht mehr existieren.
    func cleanupMissingFiles() {
        queue.sync {
            let keys = states.keys
            for k in keys where !FileManager.default.fileExists(atPath: k) {
                states.removeValue(forKey: k)
            }
        }
        saveToDisk()
    }

    private func key(for url: URL) -> String {
        url.normalizedFilePath
    }
}
