//
//  BackgroundAnalyzer.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import PDFKit
import Combine

/// Führt Analysen im Hintergrund durch (Ollama → OCR-Fallback), ohne UI.
/// Ergebnisse werden per Notification gepostet und dadurch automatisch persistiert.
final class BackgroundAnalyzer {

    private let store: DocumentStore
    private let settings: SettingsStore
    private let analysis: AnalysisManager
    private var isRunning = false

    init(store: DocumentStore, settings: SettingsStore, analysis: AnalysisManager) {
        self.store = store
        self.settings = settings
        self.analysis = analysis

        // Auf Quellordner-Events reagieren
        NotificationCenter.default.addObserver(self,
                                               selector: #selector(sourceChanged),
                                               name: .sourceFolderDidChange,
                                               object: nil)
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func sourceChanged() {
        run()
    }

    /// Kann gefahrlos mehrfach aufgerufen werden; serialisiert intern.
    func run() {
        guard !isRunning else { return }
        isRunning = true
        Task.detached(priority: .utility) { [weak self] in
            defer { self?.isRunning = false }
            await self?.processQueue()
        }
    }

    private func textFromPDF(_ url: URL) -> String {
        // kleine lokale Text-Extraktion (bis ~6 Seiten)
        guard let doc = PDFDocument(url: url) else { return "" }
        var out = ""
        for i in 0..<min(doc.pageCount, 6) {
            if let s = doc.page(at: i)?.string {
                out.append(s + "\n")
                if out.count > 8000 { break }
            }
        }
        return out.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func hasUseful(_ s: Suggestion) -> Bool {
        (s.datum != nil) || (s.korrespondent?.isEmpty == false) || (s.dokumenttyp?.isEmpty == false)
    }

    private func confidence(for s: Suggestion) -> Double {
        var c: Double = 0
        if s.korrespondent?.isEmpty == false { c += 0.33 }
        if s.dokumenttyp?.isEmpty == false { c += 0.33 }
        if s.datum != nil { c += 0.33 }
        let lower = (s.dokumenttyp ?? "").lowercased()
        if ["rechnung","mahnung","police","vertrag","offerte","gutschrift","lieferschein"].contains(where: { lower.contains($0) }) { c += 0.05 }
        return min(c, 1.0)
    }

    private func postResult(url: URL, suggestion: Suggestion) {
        let st = AnalysisState(status: .analyzed,
                               confidence: confidence(for: suggestion),
                               korrespondent: suggestion.korrespondent,
                               dokumenttyp: suggestion.dokumenttyp,
                               datum: suggestion.datum)
        // AnalysisManager updaten
        DispatchQueue.main.async {
            self.analysis.markAnalyzed(url: url, state: st)
            NotificationCenter.default.post(name: .analysisDidFinish, object: url, userInfo: ["state": st])
        }
    }

    private func postFail(url: URL) {
        DispatchQueue.main.async {
            self.analysis.markFailed(url: url)
            NotificationCenter.default.post(name: .analysisDidFail, object: url)
        }
    }

    private func shouldSkip(_ url: URL) -> Bool {
        // bereits persistiert → überspringen
        if PersistedStateStore.shared.state(for: url) != nil { return true }
        // bereits im RAM bekannt → überspringen
        if analysis.isAnalyzed(url) { return true }
        return false
    }

    private func listPDFs() -> [URL] {
        store.items.map { $0.fileURL }
    }

    private func processQueue() async {
        let files = listPDFs()
        for url in files {
            if shouldSkip(url) { continue }

            // 1) eingebetteten Text
            let embedded = textFromPDF(url)

            // 2) Ollama mit eingebettetem Text
            if !embedded.isEmpty {
                if let s = try? await OllamaClient.suggest(from: embedded,
                                                           baseURL: settings.ollamaBaseURL,
                                                           model: settings.ollamaModel),
                   hasUseful(s) {
                    postResult(url: url, suggestion: s)
                    continue
                }
            }

            // 3) OCR-Volltext
            if let ocrText = try? await OCRService.recognizeFullText(pdfURL: url), !ocrText.isEmpty {
                if let s2 = try? await OllamaClient.suggest(from: ocrText,
                                                            baseURL: settings.ollamaBaseURL,
                                                            model: settings.ollamaModel),
                   hasUseful(s2) {
                    postResult(url: url, suggestion: s2)
                    continue
                }
            }

            // 4) Heuristik
            if let s3 = try? await OCRService.suggest(from: url) {
                postResult(url: url, suggestion: s3)
            } else {
                postFail(url: url)
            }
        }
    }
}
