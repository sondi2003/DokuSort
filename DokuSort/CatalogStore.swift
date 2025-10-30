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
    struct KorrespondentResolution {
        enum Decision {
            case empty
            case partial
            case newCanonical
            case existingCanonical(name: String)
            case aliasMapped(to: String)
            case fuzzyMapped(to: String, score: Double)
            case folderMapped(to: String, score: Double)
        }

        let canonical: String
        let displayName: String
        let decision: Decision
    }

    @Published private(set) var korrespondenten: [String] = []
    @Published private(set) var dokumenttypen: [String] = []
    @Published private(set) var korrespondentAliases: [String: String] = [:]

    private let korKey = "CatalogStore.korrespondenten"
    private let typKey = "CatalogStore.dokumenttypen"
    private let aliasKey = "CatalogStore.korrespondentAliases"

    init() {
        load()
    }

    func load() {
        let d = UserDefaults.standard
        korrespondenten = d.stringArray(forKey: korKey) ?? []
        dokumenttypen = d.stringArray(forKey: typKey) ?? []
        korrespondentAliases = d.dictionary(forKey: aliasKey) as? [String: String] ?? [:]
    }

    @discardableResult
    func resolveKorrespondent(_ value: String, existingFolders: [String] = []) -> KorrespondentResolution {
        let trimmed = CorrespondentNormalizer.prettyDisplayName(from: value)
        guard !trimmed.isEmpty else {
            return KorrespondentResolution(canonical: "", displayName: "", decision: .empty)
        }

        // zu kurze Eingaben nicht sofort übernehmen (sonst entsteht beim Tippen zu viel Rauschen)
        if trimmed.count < 3 {
            return KorrespondentResolution(canonical: trimmed, displayName: trimmed, decision: .partial)
        }

        let key = CorrespondentNormalizer.normalizedKey(for: trimmed)
        if key.count < 3 {
            return KorrespondentResolution(canonical: trimmed, displayName: trimmed, decision: .partial)
        }

        if let existing = korrespondentAliases[key] {
            return KorrespondentResolution(canonical: existing, displayName: existing, decision: .aliasMapped(to: existing))
        }

        if let direct = korrespondenten.first(where: { CorrespondentNormalizer.normalizedKey(for: $0) == key }) {
            korrespondentAliases[key] = direct
            save()
            return KorrespondentResolution(canonical: direct, displayName: direct, decision: .existingCanonical(name: direct))
        }

        if let folder = existingFolders.first(where: { CorrespondentNormalizer.normalizedKey(for: $0) == key }) {
            registerKorrespondent(folder)
            korrespondentAliases[key] = folder
            save()
            return KorrespondentResolution(canonical: folder, displayName: folder, decision: .existingCanonical(name: folder))
        }

        var bestName: String? = nil
        var bestScore: Double = 0
        var fromFolder = false

        for candidate in korrespondenten {
            let score = CorrespondentNormalizer.similarity(between: trimmed, and: candidate)
            if score > bestScore {
                bestScore = score
                bestName = candidate
                fromFolder = false
            }
        }

        for candidate in existingFolders where !korrespondenten.contains(where: { $0.caseInsensitiveCompare(candidate) == .orderedSame }) {
            let score = CorrespondentNormalizer.similarity(between: trimmed, and: candidate)
            if score > bestScore {
                bestScore = score
                bestName = candidate
                fromFolder = true
            }
        }

        if let name = bestName, bestScore >= 0.82 {
            registerKorrespondent(name)
            korrespondentAliases[key] = name
            save()
            if fromFolder {
                return KorrespondentResolution(canonical: name, displayName: name, decision: .folderMapped(to: name, score: bestScore))
            } else {
                return KorrespondentResolution(canonical: name, displayName: name, decision: .fuzzyMapped(to: name, score: bestScore))
            }
        }

        let canonical = trimmed
        registerKorrespondent(canonical)
        korrespondentAliases[key] = canonical
        save()
        return KorrespondentResolution(canonical: canonical, displayName: canonical, decision: .newCanonical)
    }

    func addDokumenttyp(_ value: String) {
        let cleaned = CorrespondentNormalizer.prettyDisplayName(from: value)
        guard !cleaned.isEmpty else { return }
        if !dokumenttypen.contains(where: { $0.caseInsensitiveCompare(cleaned) == .orderedSame }) {
            dokumenttypen.append(cleaned)
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

    private func registerKorrespondent(_ value: String) {
        guard !value.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        if !korrespondenten.contains(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) {
            korrespondenten.append(value)
        }
    }

    private func save() {
        let d = UserDefaults.standard
        d.set(korrespondenten, forKey: korKey)
        d.set(dokumenttypen, forKey: typKey)
        d.set(korrespondentAliases, forKey: aliasKey)
    }

    enum Kind { case korrespondent, dokumenttyp }
}
