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
    private var states: [String: AnalysisState] = [:] // Key = fileURL.path

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
                states = decoded
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
        queue.sync { states[url.path] }
    }

    func upsert(url: URL, state: AnalysisState) {
        queue.sync {
            states[url.path] = state
        }
        saveToDisk()
    }

    func remove(url: URL) {
        queue.sync {
            states.removeValue(forKey: url.path)
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
}
