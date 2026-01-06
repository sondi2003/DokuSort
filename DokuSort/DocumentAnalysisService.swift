//
//  DocumentAnalysisService.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import Foundation
import PDFKit
import Vision

struct AnalysisConfig {
    let ollamaBaseURL: String
    let ollamaModel: String
    let ollamaPrompt: String
    // NEU: Bekannte Entitäten für Context Injection
    let knownCorrespondents: [String]
}

actor DocumentAnalysisService {
    
    struct AnalysisResult {
        let text: String
        let suggestion: Suggestion
        let source: String
    }
    
    func analyze(
        item: DocumentItem,
        config: AnalysisConfig,
        forceOCR: Bool = false
    ) async throws -> AnalysisResult {
        
        // 1. Text extrahieren
        let text = await extractBestText(from: item.fileURL, forceOCR: forceOCR)
        guard !text.isEmpty else {
            throw NSError(domain: "Analysis", code: -1, userInfo: [NSLocalizedDescriptionKey: "Kein Text konnte extrahiert werden."])
        }
        
        // 2. Prompt anreichern (Context Injection)
        var enrichedPrompt = config.ollamaPrompt
        if !config.knownCorrespondents.isEmpty {
            let list = config.knownCorrespondents.prefix(50).joined(separator: ", ") // Limitieren, um Token zu sparen
            let contextHint = """
            
            HINWEIS: Hier ist eine Liste bekannter Korrespondenten (wähle einen davon, falls passend, sonst nimm den aus dem Text):
            [\(list)]
            
            """
            // Wir fügen den Hinweis VOR dem Platzhalter {TEXT} ein
            enrichedPrompt = enrichedPrompt.replacingOccurrences(of: "{TEXT}", with: "\(contextHint)\n{TEXT}")
        } else {
             // Standard Ersetzung falls Liste leer
             enrichedPrompt = enrichedPrompt.replacingOccurrences(of: "{TEXT}", with: "{TEXT}")
        }
        
        // 3. Priorität 1: Apple Intelligence
        let aiStatus = await AppleIntelligenceClient.checkAvailability()
        if aiStatus.available {
            do {
                let suggestion = try await AppleIntelligenceClient.suggest(
                    from: text,
                    promptTemplate: enrichedPrompt
                )
                return AnalysisResult(text: text, suggestion: suggestion, source: "Apple Intelligence")
            } catch {
                print("⚠️ Apple Intelligence failed: \(error). Fallback to Ollama.")
            }
        }
        
        // 4. Priorität 2: Ollama
        if !config.ollamaBaseURL.isEmpty && !config.ollamaModel.isEmpty {
            do {
                let suggestion = try await OllamaClient.suggest(
                    from: text,
                    baseURL: config.ollamaBaseURL,
                    model: config.ollamaModel,
                    promptTemplate: enrichedPrompt
                )
                return AnalysisResult(text: text, suggestion: suggestion, source: "Ollama (\(config.ollamaModel))")
            } catch {
                print("⚠️ Ollama failed: \(error). Fallback to Heuristic.")
            }
        }
        
        // 5. Priorität 3: Heuristik
        let fallbackSuggestion = OCRService.suggest(fromText: text)
        return AnalysisResult(text: text, suggestion: fallbackSuggestion, source: "Regelbasiert")
    }
    
    // MARK: - Helper
    
    private func extractBestText(from url: URL, forceOCR: Bool) async -> String {
        if !forceOCR, let pdfText = extractPDFString(from: url), pdfText.count > 50 {
            print("📄 [Extraction] Nutze existierenden PDF-Text.")
            return pdfText
        }
        print("👁️ [Extraction] Erzwinge Vision OCR...")
        if let ocrText = try? await OCRService.recognizeFullText(pdfURL: url) {
            return ocrText
        }
        return ""
    }
    
    private func extractPDFString(from url: URL) -> String? {
        guard let pdf = PDFDocument(url: url) else { return nil }
        var fullText = ""
        for i in 0..<pdf.pageCount {
            guard let page = pdf.page(at: i) else { continue }
            if let pageText = page.string {
                fullText += pageText + "\n"
            }
        }
        return fullText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
