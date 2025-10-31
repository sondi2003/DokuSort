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
    static func suggest(from pdfURL: URL) async throws -> Suggestion {
        let text = try await recognizeFullText(pdfURL: pdfURL)
        var sug = Suggestion()
        if let d = extractDate(from: text) { sug.datum = d }
        if let k = extractKorrespondent(from: text) { sug.korrespondent = k }
        sug.dokumenttyp = extractDokumenttyp(from: text)
        return sug
    }

    /// Liefert Volltext (erste 1–2 Seiten, um schnell zu bleiben)
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

    // Heuristiken
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
        // Erweiterte Blacklist mit häufigen Störbegriffen
        let blacklist: Set<String> = [
            "rechnung", "gutschrift", "mahnung", "offerte", "bestellung", "invoice", "bill",
            "police", "vertrag", "lieferschein", "seite", "page", "datum", "date",
            "betrag", "amount", "total", "summe", "mwst", "vat", "ust", "steuer", "tax",
            "iban", "bic", "swift", "kundennummer", "customer", "reference", "referenz",
            "zahlungsziel", "payment", "fällig", "due", "lieferung", "delivery",
            "empfänger", "recipient", "absender", "sender", "betreff", "subject"
        ]

        // Kontext-Marker für explizite Absender-Kennzeichnung
        let senderMarkers = ["von:", "from:", "absender:", "sender:", "aussteller:"]

        let lines = text.split(separator: "\n", omittingEmptySubsequences: true)

        // 1. Prüfe auf explizite Marker (höchste Priorität)
        for (index, line) in lines.prefix(15).enumerated() {
            let lower = line.lowercased()
            for marker in senderMarkers {
                if lower.contains(marker) {
                    // Extrahiere Text nach dem Marker
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

        // 2. Sammle Kandidaten aus ersten Zeilen mit Scoring
        struct ScoredCandidate {
            let text: String
            let score: Double
        }

        var scoredCandidates: [ScoredCandidate] = []

        for (index, line) in lines.prefix(12).enumerated() {
            // Zeile in Tokens aufteilen (mehrere Trennzeichen)
            let tokens = line
                .replacingOccurrences(of: "\n", with: " ")
                .components(separatedBy: CharacterSet(charactersIn: ",|;·•—–()[]{}"))
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }

            for token in tokens {
                guard let validated = validateCandidate(token, blacklist: blacklist) else { continue }

                // Scoring-Faktoren
                var score: Double = 0.0

                // Position (frühere Zeilen = höherer Score)
                let positionScore = max(0, 1.0 - (Double(index) / 12.0))
                score += positionScore * 40.0  // max 40 Punkte

                // Länge (optimal 10-40 Zeichen)
                let lengthScore: Double
                if validated.count >= 10 && validated.count <= 40 {
                    lengthScore = 1.0
                } else if validated.count < 10 {
                    lengthScore = Double(validated.count) / 10.0
                } else {
                    lengthScore = max(0, 1.0 - (Double(validated.count - 40) / 60.0))
                }
                score += lengthScore * 30.0  // max 30 Punkte

                // Format-Qualität
                let hasLegalSuffix = hasCompanyLegalForm(validated)
                if hasLegalSuffix { score += 20.0 }

                let hasMultipleWords = validated.split(separator: " ").count >= 2
                if hasMultipleWords { score += 10.0 }

                // Bonus für Zeile 0-2
                if index <= 2 { score += 15.0 }

                scoredCandidates.append(ScoredCandidate(text: validated, score: score))
            }
        }

        // 3. Besten Kandidaten zurückgeben
        if let best = scoredCandidates.max(by: { $0.score < $1.score }) {
            return best.text
        }

        return nil
    }

    // Validiert einen Kandidaten-String
    private static func validateCandidate(_ text: String, blacklist: Set<String>) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Mindestlänge
        guard trimmed.count >= 3 else { return nil }

        // Maximal 80 Zeichen (sonst wahrscheinlich ganze Zeile)
        guard trimmed.count <= 80 else { return nil }

        // Muss Großbuchstaben enthalten
        guard trimmed.contains(where: { $0.isUppercase }) else { return nil }

        // Darf nicht mit Zahl beginnen
        guard let first = trimmed.unicodeScalars.first,
              !CharacterSet.decimalDigits.contains(first) else { return nil }

        // Blacklist-Check
        let lower = trimmed.lowercased()
        for blacklisted in blacklist {
            if lower.contains(blacklisted) { return nil }
        }

        // Prüfe auf zu viele Zahlen (> 30% = wahrscheinlich keine Firma)
        let digitCount = trimmed.filter { $0.isNumber }.count
        let digitRatio = Double(digitCount) / Double(trimmed.count)
        guard digitRatio < 0.3 else { return nil }

        // Prüfe auf sinnvolle Zeichen (keine reinen Sonderzeichen)
        let letterCount = trimmed.filter { $0.isLetter }.count
        guard letterCount >= 3 else { return nil }

        return trimmed
    }

    // Prüft ob Text eine Rechtsform enthält (AG, GmbH, etc.)
    private static func hasCompanyLegalForm(_ text: String) -> Bool {
        let legalForms: Set<String> = [
            "ag", "gmbh", "kg", "ohg", "ug", "eg", "se", "sa", "sàrl", "sarl",
            "srl", "oy", "ab", "as", "nv", "bv", "llc", "inc", "ltd", "plc", "co"
        ]

        let words = text.lowercased()
            .components(separatedBy: .whitespaces)
            .map { $0.trimmingCharacters(in: .punctuationCharacters) }

        for word in words {
            if legalForms.contains(word) { return true }
        }

        return false
    }

    private static func extractDokumenttyp(from text: String) -> String {
        let lower = text.lowercased()
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
