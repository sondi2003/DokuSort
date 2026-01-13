//
//  OCRService.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import PDFKit
import Vision
import AppKit

enum OCRServiceError: Error {
    case pdfLoadFailed
    case renderFailed
    case recognitionFailed
}

final class OCRService {
    
    // MARK: - Public API
    
    static func suggest(from pdfURL: URL, knownTags: [String] = []) async throws -> Suggestion {
        let text = try await recognizeFullText(pdfURL: pdfURL)
        return suggest(fromText: text, knownTags: knownTags)
    }
    
    // NEU: Parameter knownTags
    nonisolated static func suggest(fromText text: String, knownTags: [String] = []) -> Suggestion {
        var sug = Suggestion()
        if let d = extractDate(from: text) { sug.datum = d }
        if let k = extractKorrespondent(from: text) { sug.korrespondent = k }
        sug.dokumenttyp = extractDokumenttyp(from: text, knownTags: knownTags)
        return sug
    }

    static func recognizeFullText(pdfURL: URL, maxPages: Int = 2) async throws -> String {
        guard let doc = PDFDocument(url: pdfURL) else { throw OCRServiceError.pdfLoadFailed }
        var all = [String]()
        let pages = min(maxPages, doc.pageCount)
        
        for i in 0..<pages {
            guard let page = doc.page(at: i) else { continue }
            
            let dpi: CGFloat = 144
            let pageRect = page.bounds(for: .mediaBox)
            let size = NSSize(width: pageRect.width * dpi / 72, height: pageRect.height * dpi / 72)
            
            guard let cg = page.thumbnail(of: size, for: .mediaBox).cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                continue
            }
            
            let request = VNRecognizeTextRequest()
            request.recognitionLanguages = ["de-CH", "de-DE", "en-US"]
            request.minimumTextHeight = 0.01
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            let handler = VNImageRequestHandler(cgImage: cg, options: [:])
            try handler.perform([request])
            
            let lines: [String] = request.results?.compactMap { $0.topCandidates(1).first?.string } ?? []
            all.append(lines.joined(separator: "\n"))
        }
        
        let text = all.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty { throw OCRServiceError.recognitionFailed }
        return text
    }

    // MARK: - Heuristiken
    
    private static func extractDate(from text: String) -> Date? {
        let patterns = [
            #"(\d{1,2})\.(\d{1,2})\.(\d{4})"#,
            #"(\d{4})-(\d{1,2})-(\d{1,2})"#
        ]
        let ns = text as NSString
        for p in patterns {
            if let r = try? NSRegularExpression(pattern: p),
               let m = r.firstMatch(in: text, range: NSRange(location: 0, length: ns.length)), m.numberOfRanges == 4 {
                let a = ns.substring(with: m.range(at: 1))
                let b = ns.substring(with: m.range(at: 2))
                let c = ns.substring(with: m.range(at: 3))
                var comps = DateComponents()
                if p.contains(#"\."#) { comps.day = Int(a); comps.month = Int(b); comps.year = Int(c) }
                else { comps.year = Int(a); comps.month = Int(b); comps.day = Int(c) }
                return Calendar.current.date(from: comps)
            }
        }
        return nil
    }

    private static func extractKorrespondent(from text: String) -> String? {
        let blacklist: Set<String> = [
            "rechnung", "gutschrift", "mahnung", "offerte", "bestellung", "invoice", "bill",
            "police", "vertrag", "lieferschein", "seite", "page", "datum", "date",
            "betrag", "amount", "total", "summe", "mwst", "vat", "ust", "steuer", "tax",
            "iban", "bic", "swift", "kundennummer", "customer", "reference", "referenz",
            "zahlungsziel", "payment", "fällig", "due", "lieferung", "delivery",
            "empfänger", "recipient", "absender", "sender", "betreff", "subject"
        ]

        let senderMarkers = ["von:", "from:", "absender:", "sender:", "aussteller:"]
        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        for line in lines.prefix(15) {
            let lower = line.lowercased()
            for marker in senderMarkers {
                if lower.contains(marker) {
                    if let range = lower.range(of: marker) {
                        let afterMarker = String(line[range.upperBound...])
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        if let candidate = validateCandidate(afterMarker, blacklist: blacklist) {
                            return candidate
                        }
                    }
                }
            }
        }

        struct ScoredCandidate { let text: String; let score: Double }
        var scoredCandidates: [ScoredCandidate] = []

        for (index, line) in lines.prefix(12).enumerated() {
            let tokens = line
                .replacingOccurrences(of: "\n", with: " ")
                .components(separatedBy: CharacterSet(charactersIn: ",|;·•—–()[]{}"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for token in tokens {
                guard let validated = validateCandidate(token, blacklist: blacklist) else { continue }
                var score: Double = 0.0
                let positionScore = max(0, 1.0 - (Double(index) / 12.0))
                score += positionScore * 40.0
                let lengthScore: Double
                if validated.count >= 10 && validated.count <= 40 { lengthScore = 1.0 }
                else if validated.count < 10 { lengthScore = Double(validated.count) / 10.0 }
                else { lengthScore = max(0, 1.0 - (Double(validated.count - 40) / 60.0)) }
                score += lengthScore * 30.0
                if hasCompanyLegalForm(validated) { score += 20.0 }
                if validated.split(separator: " ").count >= 2 { score += 10.0 }
                if index <= 2 { score += 15.0 }
                scoredCandidates.append(ScoredCandidate(text: validated, score: score))
            }
        }

        if let best = scoredCandidates.max(by: { $0.score < $1.score }) {
            return best.text
        }
        return nil
    }

    private static func validateCandidate(_ text: String, blacklist: Set<String>) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3 else { return nil }
        guard trimmed.count <= 80 else { return nil }
        guard trimmed.contains(where: { $0.isUppercase }) else { return nil }
        guard let first = trimmed.unicodeScalars.first, !CharacterSet.decimalDigits.contains(first) else { return nil }
        let lower = trimmed.lowercased()
        for blacklisted in blacklist { if lower.contains(blacklisted) { return nil } }
        let digitCount = trimmed.filter { $0.isNumber }.count
        if Double(digitCount) / Double(trimmed.count) >= 0.3 { return nil }
        let letterCount = trimmed.filter { $0.isLetter }.count
        guard letterCount >= 3 else { return nil }
        return trimmed
    }

    private static func hasCompanyLegalForm(_ text: String) -> Bool {
        let legalForms: Set<String> = [
            "ag", "gmbh", "kg", "ohg", "ug", "eg", "se", "sa", "sàrl", "sarl",
            "srl", "oy", "ab", "as", "nv", "bv", "llc", "inc", "ltd", "plc", "co"
        ]
        let words = text.lowercased().components(separatedBy: .whitespaces).map { $0.trimmingCharacters(in: .punctuationCharacters) }
        for word in words { if legalForms.contains(word) { return true } }
        return false
    }

    // NEU: Prüft zuerst die bekannten Tags
    private static func extractDokumenttyp(from text: String, knownTags: [String]) -> String {
        let lower = text.lowercased()
        
        // 1. Priorität: Bekannte Tags aus dem Katalog
        // Wir sortieren nach Länge (absteigend), damit spezifischere Begriffe vor allgemeinen matchen
        // (z.B. "Spezielle Rechnung" vor "Rechnung")
        let sortedTags = knownTags.sorted { $0.count > $1.count }
        for tag in sortedTags {
            if lower.contains(tag.lowercased()) {
                return tag
            }
        }
        
        // 2. Fallback: Hardcoded Keywords
        if lower.contains("rechnung") || lower.contains("invoice") { return "Rechnung" }
        if lower.contains("mahnung") { return "Mahnung" }
        if lower.contains("gutschrift") || lower.contains("credit") { return "Gutschrift" }
        if lower.contains("offerte") || lower.contains("angebot") || lower.contains("quote") { return "Offerte" }
        if lower.contains("police") || lower.contains("versicherungsschein") { return "Police" }
        if lower.contains("vertrag") { return "Vertrag" }
        if lower.contains("lieferschein") || lower.contains("delivery") { return "Lieferschein" }
        
        return "Dokument"
    }
}
