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
    
    // MARK: - Correspondents
    
    func addCorrespondent(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        
        if !correspondents.contains(where: { $0.localizedCaseInsensitiveCompare(trimmed) == .orderedSame }) {
            correspondents.append(trimmed)
            correspondents.sort()
            save()
        }
    }
    
    func deleteCorrespondent(at index: Int) { // Fehlte vorher
        guard correspondents.indices.contains(index) else { return }
        correspondents.remove(at: index)
        save()
    }
    
    func deleteCorrespondent(_ name: String) { // Optional: Löschen nach Name
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
    
    func deleteTag(at index: Int) { // Fehlte vorher
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
