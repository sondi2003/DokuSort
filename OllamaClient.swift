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

        // Verbesserter Prompt mit Few-Shot-Learning und klaren Anweisungen
        let prompt = """
        Du bist ein Experte für Dokumenten-Analyse. Deine Aufgabe ist es, aus deutschen Dokumenten folgende Informationen zu extrahieren:

        1. **datum**: Das Rechnungs-/Dokumentdatum (Format: YYYY-MM-DD). Suche nach dem HAUPTDATUM des Dokuments, nicht nach Fälligkeits- oder Lieferdaten.

        2. **korrespondent**: Der Name der Firma oder Organisation, die das Dokument ausgestellt hat (NICHT der Empfänger).
           - Bevorzuge die offizielle Firmenbezeichnung (z.B. "Swisscom AG" statt nur "Swisscom")
           - Ignoriere Abteilungsnamen oder Ansprechpersonen
           - Maximal 50 Zeichen
           - Keine Adresszeilen

        3. **dokumenttyp**: Die Art des Dokuments. Wähle aus:
           - "Rechnung" (für Rechnungen, Invoices)
           - "Mahnung" (für Zahlungserinnerungen)
           - "Gutschrift" (für Credits)
           - "Offerte" (für Angebote, Quotes)
           - "Police" (für Versicherungspolizzen)
           - "Vertrag" (für Verträge, Contracts)
           - "Lieferschein" (für Delivery Notes)
           - "Dokument" (falls nichts passt)

        **WICHTIG**:
        - Der Korrespondent ist der ABSENDER/AUSSTELLER, nicht der Empfänger
        - Bei mehreren möglichen Namen: Wähle den, der am Anfang des Dokuments steht
        - Wenn unsicher: Bevorzuge kürzere, klarere Namen

        **Beispiele:**

        Beispiel 1 - Rechnung:
        Input: "Swisscom AG\nHardturmstrasse 3\n8005 Zürich\n\nRechnung Nr. 2024-1234\nDatum: 15.03.2024\n\nAn: Max Mustermann..."
        Output: {"datum": "2024-03-15", "korrespondent": "Swisscom AG", "dokumenttyp": "Rechnung"}

        Beispiel 2 - Versicherung:
        Input: "AXA Versicherungen\nGeneraldirektion\n\nVersicherungspolice Nr. 123456\nGültig ab: 01.01.2024..."
        Output: {"datum": "2024-01-01", "korrespondent": "AXA Versicherungen", "dokumenttyp": "Police"}

        Beispiel 3 - Offerte:
        Input: "ACME GmbH\nOffertnummer: OFF-2024-089\nDatum: 20.02.2024\n\nSehr geehrter Herr..."
        Output: {"datum": "2024-02-24", "korrespondent": "ACME GmbH", "dokumenttyp": "Offerte"}

        **Antworte NUR mit dem JSON-Objekt. Keine Erklärungen, kein Fließtext, keine Code-Blöcke.**

        Zu analysierender Text:
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
