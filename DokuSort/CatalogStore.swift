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
    @Published private(set) var tags: [String] = [] // In der UI als "Dokumenttypen" verwendet
    
    private let correspondentsKey = "Catalog_Correspondents"
    private let tagsKey = "Catalog_Tags"
    
    init() {
        load()
    }
    
    // MARK: - Matching Logic (NEU)
    
    /// Versucht, einen bestehenden Eintrag zu finden, der dem Kandidaten entspricht.
    /// Nutzt den CorrespondentNormalizer, um Suffixe (AG, GmbH) zu ignorieren.
    /// Beispiel: Input "UBS AG" findet "UBS", wenn "UBS" bereits existiert.
    func findBestMatch(for candidate: String) -> String? {
        let trimmedCandidate = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedCandidate.isEmpty { return nil }
        
        // 1. Exakter Match (Case Insensitive)
        if let exact = correspondents.first(where: { $0.localizedCaseInsensitiveCompare(trimmedCandidate) == .orderedSame }) {
            return exact
        }
        
        // 2. Normalisierter Match (nutzt deine CorrespondentNormalizer Logik)
        // Wir suchen nach einem Eintrag, dessen "normalizedKey" identisch ist.
        // Der Normalizer entfernt "AG", "GmbH" etc. -> "UBS AG" wird zu "ubs", "UBS" wird zu "ubs".
        let candidateKey = CorrespondentNormalizer.normalizedKey(for: trimmedCandidate)
        
        if let normalizedMatch = correspondents.first(where: {
            CorrespondentNormalizer.normalizedKey(for: $0) == candidateKey
        }) {
            return normalizedMatch
        }
        
        return nil
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
    
    // Einzelnen Tag hinzufügen (für UI)
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
