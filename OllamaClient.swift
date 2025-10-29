//
//  OllamaClient.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

enum OllamaError: Error, LocalizedError {
    case invalidURL
    case requestFailed(String)
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Ollama URL ist ungültig."
        case .requestFailed(let msg): return "Ollama Anfrage fehlgeschlagen: \(msg)"
        case .decodeFailed: return "Ollama Antwort konnte nicht gelesen werden."
        }
    }
}

struct OllamaSuggestionPayload: Codable {
    let datum: String?
    let korrespondent: String?
    let dokumenttyp: String?
}

final class OllamaClient {
    static func suggest(from text: String, baseURL: String, model: String) async throws -> Suggestion {
        guard let url = URL(string: "\(baseURL)/api/generate") else {
            throw OllamaError.invalidURL
        }

        // Kurzer Prompt: gib JSON zurück
        let prompt = """
        Extrahiere aus folgendem deutschen Dokumenttext die Felder als kompaktes JSON:
        - datum (im Format YYYY-MM-DD, falls erkennbar)
        - korrespondent (Firma/Absender, kurz)
        - dokumenttyp (z. B. Rechnung, Mahnung, Police, Vertrag, Offerte)

        Antworte NUR mit einem JSON-Objekt. Kein Fliesstext, kein Codeblock.

        Text:
        \(text.prefix(4000))
        """

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false
        ]

        let reqData = try JSONSerialization.data(withJSONObject: body)
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = reqData

        let (data, resp) = try await URLSession.shared.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            let msg = String(data: data, encoding: .utf8) ?? "Unbekannter Fehler"
            throw OllamaError.requestFailed(msg)
        }

        // Ollama antwortet mit {"response": "..."}; darin steckt unser JSON
        struct Gen: Codable { let response: String }
        guard let gen = try? JSONDecoder().decode(Gen.self, from: data) else {
            throw OllamaError.decodeFailed
        }

        // Versuche, das JSON aus response zu decodieren
        // Entferne evtl. Backticks/Codefences
        let cleaned = gen.response
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let payload = try? JSONDecoder().decode(OllamaSuggestionPayload.self, from: jsonData) else {
            throw OllamaError.decodeFailed
        }

        var sug = Suggestion()
        if let d = payload.datum, let date = isoDate(d) { sug.datum = date }
        if let k = payload.korrespondent, !k.isEmpty { sug.korrespondent = k }
        if let t = payload.dokumenttyp, !t.isEmpty { sug.dokumenttyp = t }
        return sug
    }

    private static func isoDate(_ s: String) -> Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.timeZone = .current
        return f.date(from: s)
    }
}
