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

        func containsCaseInsensitive(_ array: [String], _ value: String) -> Bool {
            array.contains { $0.caseInsensitiveCompare(value) == .orderedSame }
        }

        let canonicalCandidates: [String]
        let additionalCandidates: [String]
        if existingFolders.isEmpty {
            canonicalCandidates = korrespondenten
            additionalCandidates = []
        } else {
            canonicalCandidates = existingFolders
            additionalCandidates = korrespondenten.filter { !containsCaseInsensitive(existingFolders, $0) }
        }

        if let existing = korrespondentAliases[key] {
            if containsCaseInsensitive(canonicalCandidates, existing) || containsCaseInsensitive(additionalCandidates, existing) {
                return KorrespondentResolution(canonical: existing, displayName: existing, decision: .aliasMapped(to: existing))
            } else {
                korrespondentAliases.removeValue(forKey: key)
                save()
            }
        }

        let directSources = canonicalCandidates + additionalCandidates
        if let direct = directSources.first(where: { CorrespondentNormalizer.normalizedKey(for: $0) == key }) {
            registerKorrespondent(direct)
            korrespondentAliases[key] = direct
            save()
            return KorrespondentResolution(canonical: direct, displayName: direct, decision: .existingCanonical(name: direct))
        }

        var bestCandidate: (name: String, bigram: Double, keyScore: Double, fromFolder: Bool)? = nil

        func considerCandidate(_ candidate: String, fromFolder: Bool) {
            let bigramScore = CorrespondentNormalizer.similarity(between: trimmed, and: candidate)
            let candidateKey = CorrespondentNormalizer.normalizedKey(for: candidate)
            let keyScore = CorrespondentNormalizer.normalizedKeySimilarity(betweenNormalized: key, andNormalized: candidateKey)
            let combined = max(bigramScore, keyScore)
            guard combined > (bestCandidate.map { max($0.bigram, $0.keyScore) } ?? -1) else { return }

            if let current = bestCandidate, combined == max(current.bigram, current.keyScore) {
                if keyScore <= current.keyScore { return }
            }

            bestCandidate = (candidate, bigramScore, keyScore, fromFolder)
        }

        canonicalCandidates.forEach { considerCandidate($0, fromFolder: true) }
        additionalCandidates.forEach { considerCandidate($0, fromFolder: false) }

        if let best = bestCandidate {
            let combinedScore = max(best.bigram, best.keyScore)
            if best.bigram >= 0.82 || best.keyScore >= 0.9 {
                registerKorrespondent(best.name)
                korrespondentAliases[key] = best.name
                save()
                if best.fromFolder {
                    return KorrespondentResolution(
                        canonical: best.name,
                        displayName: best.name,
                        decision: .folderMapped(to: best.name, score: combinedScore)
                    )
                } else {
                    return KorrespondentResolution(
                        canonical: best.name,
                        displayName: best.name,
                        decision: .fuzzyMapped(to: best.name, score: combinedScore)
                    )
                }
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
