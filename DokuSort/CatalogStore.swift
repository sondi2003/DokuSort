//
//  CatalogStore.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import Foundation
import Combine

@MainActor
final class CatalogStore: ObservableObject {
    static let shared = CatalogStore()
    
    @Published private(set) var correspondents: [String] = []
    @Published private(set) var tags: [String] = []
    
    private let correspondentsKey = "Catalog_Correspondents"
    private let tagsKey = "Catalog_Tags"
    
    init() {
        load()
    }
    
    // MARK: - Matching Logic (VERBESSERT)
    
    /// Findet den besten Match unter Berücksichtigung der Ähnlichkeit.
    /// Wenn "Apple Distribution" gesucht wird und ["Apple", "Apple Distribution"] existieren,
    /// gewinnt jetzt "Apple Distribution", weil die Distanz zum Original 0 ist.
    func findBestMatch(for candidate: String) -> String? {
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedCandidate.isEmpty else { return nil }
        
        // 1. Exakter Match (Case Insensitive) - Hat immer Vorrang
        if let exact = correspondents.first(where: { $0.localizedCaseInsensitiveCompare(trimmedCandidate) == .orderedSame }) {
            return exact
        }
        
        // 2. Normalisierter Match mit Qualitäts-Check
        // Wir suchen ALLE Einträge, die denselben "vereinfachten" Key haben.
        // (z.B. falls Normalizer "Distribution" ignoriert, wären "Apple" und "Apple Distribution" beides Treffer)
        let candidateKey = CorrespondentNormalizer.normalizedKey(for: trimmedCandidate)
        
        let potentialMatches = correspondents.filter {
            CorrespondentNormalizer.normalizedKey(for: $0) == candidateKey
        }
        
        guard !potentialMatches.isEmpty else { return nil }
        
        // 3. Den besten Match auswählen (Geringste Levenshtein-Distanz zum ORIGINAL)
        // Wir vergleichen mit dem URSPRÜNGLICHEN candidate, nicht dem key.
        return potentialMatches.min(by: { a, b in
            a.levenshteinDistance(to: trimmedCandidate) < b.levenshteinDistance(to: trimmedCandidate)
        })
    }
    
    // MARK: - Correspondents
    
    func addCorrespondent(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        // Prüfen, ob exakt dieser Name schon existiert (Case Insensitive)
        if !correspondents.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            correspondents.append(trimmed)
            correspondents.sort()
            save()
            print("💾 [Catalog] Korrespondent gelernt: \(trimmed)")
        }
    }
    
    func deleteCorrespondent(at index: Int) {
        guard correspondents.indices.contains(index) else { return }
        correspondents.remove(at: index)
        save()
    }
    
    func deleteCorrespondent(_ name: String) {
        if let index = correspondents.firstIndex(of: name) {
            correspondents.remove(at: index)
            save()
        }
    }
    
    // MARK: - Tags / Dokumenttypen
    
    func addTags(_ newTags: [String]) {
        var changed = false
        for tag in newTags {
            let trimmed = tag.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            
            if !tags.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
                tags.append(trimmed)
                changed = true
            }
        }
        if changed {
            tags.sort()
            save()
        }
    }
    
    func addTag(_ name: String) {
        addTags([name])
    }
    
    func deleteTag(at index: Int) {
        guard tags.indices.contains(index) else { return }
        tags.remove(at: index)
        save()
    }
    
    // MARK: - Persistence
    
    private func save() {
        UserDefaults.standard.set(correspondents, forKey: correspondentsKey)
        UserDefaults.standard.set(tags, forKey: tagsKey)
    }
    
    private func load() {
        self.correspondents = UserDefaults.standard.stringArray(forKey: correspondentsKey) ?? []
        self.tags = UserDefaults.standard.stringArray(forKey: tagsKey) ?? []
    }
}

// MARK: - String Similarity Helper

fileprivate extension String {
    // Berechnet die Levenshtein-Distanz (Anzahl der Änderungen um String A zu B zu machen)
    func levenshteinDistance(to other: String) -> Int {
        let s1 = Array(self)
        let s2 = Array(other)
        let m = s1.count
        let n = s2.count
        
        if m == 0 { return n }
        if n == 0 { return m }
        
        var d = [[Int]](repeating: [Int](repeating: 0, count: n + 1), count: m + 1)
        
        for i in 0...m { d[i][0] = i }
        for j in 0...n { d[0][j] = j }
        
        for i in 1...m {
            for j in 1...n {
                let cost = (s1[i - 1] == s2[j - 1]) ? 0 : 1
                d[i][j] = Swift.min(
                    d[i - 1][j] + 1,      // Deletion
                    d[i][j - 1] + 1,      // Insertion
                    d[i - 1][j - 1] + cost // Substitution
                )
            }
        }
        return d[m][n]
    }
}
