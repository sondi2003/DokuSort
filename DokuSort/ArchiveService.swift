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
        
        let safeKorr = sanitize(item.correspondent.isEmpty ? "Unbekannt" : item.correspondent)
        let safeType = sanitize(item.tags.first ?? "Dokument")
        
        return "\(dateStr)_\(safeKorr)_\(safeType).pdf"
    }
    
    // WICHTIG: Das muss nun auf dem MainActor laufen, um den CatalogStore zu updaten
    @MainActor
    static func archive(
        item: DocumentItem,
        destinationFolder: URL,
        organizeByYear: Bool = true
    ) throws -> URL {
        // 1. Validierung
        guard !item.correspondent.isEmpty else { throw ArchiveError.missingMetadata }
        
        // 2. LERNEN: Wir füttern das Gehirn
        CatalogStore.shared.addCorrespondent(item.correspondent)
        CatalogStore.shared.addTags(item.tags)
        
        // 3. Ordnerstruktur erstellen
        let safeCorrespondent = sanitize(item.correspondent)
        var targetDir = destinationFolder.appendingPathComponent(safeCorrespondent, isDirectory: true)
        try createDir(targetDir)
        
        if organizeByYear {
            let year = Calendar.current.component(.year, from: item.date)
            targetDir = targetDir.appendingPathComponent("\(year)", isDirectory: true)
            try createDir(targetDir)
        }
        
        // 4. Zielnamen generieren
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
    
    private static func sanitize(_ text: String) -> String {
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return text
            .components(separatedBy: invalidCharacters)
            .joined(separator: "")
            .replacingOccurrences(of: " ", with: "_")
            .trimmingCharacters(in: .whitespaces)
    }
}
