//
//  ArchiveService.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import Foundation
import PDFKit

enum ArchiveError: LocalizedError {
    case missingMetadata
    case destinationNotReachable
    case copyFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .missingMetadata: return "Metadaten (Datum oder Korrespondent) fehlen."
        case .destinationNotReachable: return "Zielordner ist nicht erreichbar."
        case .copyFailed(let msg): return "Fehler beim Verschieben: \(msg)"
        }
    }
}

final class ArchiveService {
    
    static func generateFilename(for item: DocumentItem) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let dateStr = formatter.string(from: item.date)
        
        // Für Dateinamen wollen wir vielleicht weiterhin Unterstriche statt Leerzeichen,
        // um Probleme mit alten Dateisystemen/Scripts zu vermeiden.
        // Falls du auch im Dateinamen Leerzeichen willst, setze replaceSpaces auf false.
        let safeKorr = sanitize(item.correspondent.isEmpty ? "Unbekannt" : item.correspondent, replaceSpaces: true)
        let safeType = sanitize(item.tags.first ?? "Dokument", replaceSpaces: true)
        
        return "\(dateStr)_\(safeKorr)_\(safeType).pdf"
    }
    
    @MainActor
    static func archive(
        item: DocumentItem,
        destinationFolder: URL,
        organizeByYear: Bool = true
    ) throws -> URL {
        // 1. Validierung
        guard !item.correspondent.isEmpty else { throw ArchiveError.missingMetadata }
        
        // 2. INTELLIGENTES MATCHING & LERNEN
        // Prüfen, ob wir diesen Korrespondenten schon kennen (ignoriere AG/GmbH Suffixe)
        // Wenn item.correspondent = "UBS AG", aber "UBS" im Katalog ist -> nutze "UBS"
        let bestMatch = CatalogStore.shared.findBestMatch(for: item.correspondent)
        
        // Wenn wir einen Match gefunden haben, nutzen wir diesen für den Ordnernamen.
        // Wenn nicht, nutzen wir den neu erkannten Namen.
        let targetCorrespondentName = bestMatch ?? item.correspondent
        
        // Den ursprünglich erkannten Namen trotzdem zum Katalog hinzufügen, falls er neu ist
        // (oder sollen wir nur den targetName speichern? Meist ist es besser, Variationen zu kennen
        // aber auf einen Hauptordner zu mappen. Für jetzt speichern wir den Input).
        CatalogStore.shared.addCorrespondent(targetCorrespondentName)
        CatalogStore.shared.addTags(item.tags)
        
        // 3. Ordnerstruktur erstellen
        // Hier: replaceSpaces: false -> Erlaubt "UBS AG" statt "UBS_AG"
        let safeFolderString = sanitize(targetCorrespondentName, replaceSpaces: false)
        
        var targetDir = destinationFolder.appendingPathComponent(safeFolderString, isDirectory: true)
        try createDir(targetDir)
        
        if organizeByYear {
            let year = Calendar.current.component(.year, from: item.date)
            targetDir = targetDir.appendingPathComponent("\(year)", isDirectory: true)
            try createDir(targetDir)
        }
        
        // 4. Zielnamen generieren
        // Hinweis: Der Dateiname wird basierend auf den Item-Daten generiert.
        // Wenn du willst, dass auch im Dateinamen der "saubere" Name (z.B. UBS statt UBS AG) steht,
        // müsstest du das item temporär kopieren/anpassen.
        // Aktuell bleibt der Dateiname wie erkannt, nur der Ordner wird "gemerged".
        let newFilename = generateFilename(for: item)
        var destinationURL = targetDir.appendingPathComponent(newFilename)
        
        var counter = 1
        let baseName = (newFilename as NSString).deletingPathExtension
        let ext = (newFilename as NSString).pathExtension
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            destinationURL = targetDir.appendingPathComponent("\(baseName)_\(counter).\(ext)")
            counter += 1
        }
        
        // 5. Verschieben
        do {
            try FileManager.default.moveItem(at: item.fileURL, to: destinationURL)
            print("✅ [Archive] Verschoben nach: \(destinationURL.path)")
            return destinationURL
        } catch {
            throw ArchiveError.copyFailed(error.localizedDescription)
        }
    }
    
    private static func createDir(_ url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    // NEU: Parameter replaceSpaces steuert die Unterstriche
    private static func sanitize(_ text: String, replaceSpaces: Bool) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        var result = text
            .components(separatedBy: invalidCharacters)
            .joined(separator: "")
            .trimmingCharacters(in: .whitespaces)
        
        if replaceSpaces {
            result = result.replacingOccurrences(of: " ", with: "_")
        }
        
        return result
    }
}
