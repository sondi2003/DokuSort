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
        // Kopfbereich nehmen
        let firstLines = text.split(separator: "\n").prefix(10).joined(separator: " ")
        let blacklist = ["rechnung", "gutschrift", "mahnung", "offerte", "bestellung", "invoice", "bill", "police", "vertrag", "lieferschein"]
        let tokens = firstLines
            .replacingOccurrences(of: "\n", with: " ")
            .components(separatedBy: CharacterSet(charactersIn: ",|;·•—–-()[]{}"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let candidates = tokens.filter { t in
            let lower = t.lowercased()
            guard !blacklist.contains(where: { lower.contains($0) }) else { return false }
            guard t.count >= 3 else { return false }
            guard let first = t.unicodeScalars.first,
                  !CharacterSet.decimalDigits.contains(first) else { return false }
            return t.contains(where: { $0.isUppercase })
        }
        return candidates.sorted { $0.count > $1.count }.first
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
