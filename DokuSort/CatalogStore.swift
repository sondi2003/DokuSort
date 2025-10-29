//
//  CatalogStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine

@MainActor
final class CatalogStore: ObservableObject {
    @Published private(set) var korrespondenten: [String] = []
    @Published private(set) var dokumenttypen: [String] = []

    private let korKey = "CatalogStore.korrespondenten"
    private let typKey = "CatalogStore.dokumenttypen"

    init() {
        load()
    }

    func load() {
        let d = UserDefaults.standard
        korrespondenten = d.stringArray(forKey: korKey) ?? []
        dokumenttypen = d.stringArray(forKey: typKey) ?? []
    }

    func addKorrespondent(_ value: String) {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !korrespondenten.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            korrespondenten.append(value)
            save()
        }
    }

    func addDokumenttyp(_ value: String) {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !dokumenttypen.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            dokumenttypen.append(value)
            save()
        }
    }

    func suggestions(for input: String, in kind: Kind, limit: Int = 8) -> [String] {
        let source = (kind == .korrespondent) ? korrespondenten : dokumenttypen
        let needle = input.lowercased()
        guard !needle.isEmpty else { return Array(source.prefix(limit)) }
        // Prefix bevorzugen, sonst Substring
        let prefix = source.filter { $0.lowercased().hasPrefix(needle) }
        if prefix.count >= limit { return Array(prefix.prefix(limit)) }
        let rest = source.filter { $0.lowercased().contains(needle) && !$0.lowercased().hasPrefix(needle) }
        return Array((prefix + rest).prefix(limit))
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(korrespondenten, forKey: korKey)
        d.set(dokumenttypen, forKey: typKey)
    }

    enum Kind { case korrespondent, dokumenttyp }
}
