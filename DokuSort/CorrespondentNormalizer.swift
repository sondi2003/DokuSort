//
//  CorrespondentNormalizer.swift
//  DokuSort
//
//  Created by OpenAI Assistant on 2025-02-15.
//

import Foundation

struct CorrespondentNormalizer {
    private static let legalSuffixes: Set<String> = [
        "ag", "gmbh", "kg", "ohg", "ug", "eg", "egmbh", "se", "sa", "sarl", "sàrl",
        "srl", "oy", "ab", "as", "nv", "bv", "llc", "inc", "ltd", "plc", "co", "co."
    ]

    static func collapsedWhitespace(_ value: String) -> String {
        let components = value.split { $0.isWhitespace }
        return components.joined(separator: " ")
    }

    static func normalizedKey(for value: String) -> String {
        let folded = fold(value)
        let stripped = stripLegalSuffixes(from: folded)
        let filtered = stripped.filter { $0.isLetter || $0.isNumber }
        return filtered
    }

    static func prettyDisplayName(from value: String) -> String {
        collapsedWhitespace(value.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    static func similarity(between lhs: String, and rhs: String) -> Double {
        let left = bigrams(for: normalizeForSimilarity(lhs))
        let right = bigrams(for: normalizeForSimilarity(rhs))
        guard !left.isEmpty, !right.isEmpty else { return 0 }

        let leftCounts = counts(for: left)
        let rightCounts = counts(for: right)

        var intersection = 0
        for (key, lCount) in leftCounts {
            if let rCount = rightCounts[key] {
                intersection += min(lCount, rCount)
            }
        }

        let total = left.count + right.count
        if total == 0 { return 0 }
        return Double(2 * intersection) / Double(total)
    }

    private static func normalizeForSimilarity(_ value: String) -> String {
        let folded = fold(value)
        let stripped = stripLegalSuffixes(from: folded)
        let allowed = CharacterSet.alphanumerics.union(.whitespaces)
        let mapped = stripped.unicodeScalars.map { allowed.contains($0) ? Character($0) : " " }
        return collapsedWhitespace(String(mapped))
    }

    private static func fold(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func stripLegalSuffixes(from value: String) -> String {
        let trimmed = collapsedWhitespace(value)
        var parts = trimmed.split(separator: " ")
        while parts.count > 1 {
            let last = parts.last!.trimmingCharacters(in: .punctuationCharacters)
            if legalSuffixes.contains(last.lowercased()) {
                parts.removeLast()
                continue
            }
            break
        }
        return parts.joined(separator: " ")
    }

    private static func bigrams(for value: String) -> [String] {
        guard value.count >= 2 else { return [] }
        var result: [String] = []
        let characters = Array(value)
        for index in 0..<(characters.count - 1) {
            let gram = String(characters[index]) + String(characters[index + 1])
            result.append(gram)
        }
        return result
    }

    private static func counts(for grams: [String]) -> [String: Int] {
        var dict: [String: Int] = [:]
        for gram in grams {
            dict[gram, default: 0] += 1
        }
        return dict
    }
}
