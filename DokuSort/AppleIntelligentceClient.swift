//
//  AppleIntelligenceClient.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import Foundation
import FoundationModels

enum AppleIntelligenceError: Error, LocalizedError {
    case notAvailable(String)
    case generationFailed(String)
    case decodeFailed
    
    var errorDescription: String? {
        switch self {
        case .notAvailable(let reason): return "Apple Intelligence nicht verfügbar: \(reason)"
        case .generationFailed(let msg): return "Generierung fehlgeschlagen: \(msg)"
        case .decodeFailed: return "Antwort konnte nicht als JSON gelesen werden."
        }
    }
}

private struct AISuggestionPayload: Codable {
    let datum: String?
    let korrespondent: String?
    let dokumenttyp: String?
}

final class AppleIntelligenceClient {
    
    // NEU: 'async', da SystemLanguageModel potenziell MainActor benötigt
    static func checkAvailability() async -> (available: Bool, reason: String?) {
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            return (true, nil)
        case .unavailable(let reason):
            switch reason {
            case .appleIntelligenceNotEnabled: return (false, "Apple Intelligence ist deaktiviert.")
            case .deviceNotEligible: return (false, "Gerät nicht unterstützt.")
            case .modelNotReady: return (false, "Modell wird geladen.")
            @unknown default: return (false, "Unbekannter Grund.")
            }
        @unknown default:
            return (false, "Status unbekannt.")
        }
    }
    
    static func suggest(from text: String, promptTemplate: String) async throws -> Suggestion {
        // NEU: await
        let status = await checkAvailability()
        guard status.available else {
            throw AppleIntelligenceError.notAvailable(status.reason ?? "N/A")
        }
        
        let model = SystemLanguageModel.default
        let session = LanguageModelSession(model: model)
        
        let prompt = promptTemplate.replacingOccurrences(of: "{TEXT}", with: String(text.prefix(10000)))
        
        do {
            let response = try await session.respond(to: prompt)
            let content = response.content
            
            let cleaned = content
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            guard let jsonData = cleaned.data(using: .utf8),
                  let payload = try? JSONDecoder().decode(AISuggestionPayload.self, from: jsonData) else {
                throw AppleIntelligenceError.decodeFailed
            }
            
            var sug = Suggestion()
            if let d = payload.datum, let date = isoDate(d) { sug.datum = date }
            if let k = payload.korrespondent, !k.isEmpty { sug.korrespondent = k }
            if let t = payload.dokumenttyp, !t.isEmpty { sug.dokumenttyp = t }
            
            return sug
            
        } catch let error as AppleIntelligenceError {
            throw error
        } catch {
            throw AppleIntelligenceError.generationFailed(error.localizedDescription)
        }
    }
    
    private static func isoDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: s)
    }
}
