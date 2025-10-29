//
//  FileOps.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

enum ConflictStrategy {
    case autoSuffix
}

enum ConflictPolicy: String, Codable, CaseIterable {
    case ask
    case autoSuffix
    case overwrite
}

enum PlaceMode: Equatable {
    case move
    case copy(deleteOriginalAfterCopy: Bool)
}

struct PlacementResult {
    let sourceURL: URL
    let finalURL: URL
    let wasCopied: Bool
}

enum FileOpsError: Error, LocalizedError {
    case noArchiveBase
    case cannotCreateDir(URL)
    case nameConflict(URL)                 // <— neu: signalisiert Kollision
    case moveFailed(Error)
    case copyFailed(Error)
    case deleteOriginalFailed(Error)

    var errorDescription: String? {
        switch self {
        case .noArchiveBase: return "Kein Archiv-Basisordner gewählt."
        case .cannotCreateDir(let url): return "Zielordner konnte nicht erstellt werden: \(url.path)"
        case .nameConflict(let url): return "Dateiname bereits vorhanden: \(url.lastPathComponent)"
        case .moveFailed(let err): return "Verschieben fehlgeschlagen: \(err.localizedDescription)"
        case .copyFailed(let err): return "Kopieren fehlgeschlagen: \(err.localizedDescription)"
        case .deleteOriginalFailed(let err): return "Original konnte nach dem Kopieren nicht gelöscht werden: \(err.localizedDescription)"
        }
    }
}

final class FileOps {

    static func plannedTargetURL(
        meta: DocumentMetadata,
        archiveBaseURL: URL
    ) throws -> (dir: URL, candidate: URL) {

        let targetDir = archiveBaseURL
            .appendingPathComponent(safeFolderName(meta.korrespondent.isEmpty ? "Unbekannt" : meta.korrespondent))
            .appendingPathComponent(meta.jahr)

        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd"
        let dateStr = df.string(from: meta.datum)
        let typ = safeFileName(meta.dokumenttyp.isEmpty ? "Dokument" : meta.dokumenttyp)
        let baseName = "\(dateStr)_\(typ)"
        let candidate = targetDir.appendingPathComponent("\(baseName).pdf")

        return (dir: targetDir, candidate: candidate)
    }

    static func place(
        item: DocumentItem,
        meta: DocumentMetadata,
        archiveBaseURL: URL,
        mode: PlaceMode = .move,
        conflictPolicy: ConflictPolicy = .ask
    ) throws -> PlacementResult {

        let (targetDir, baseCandidate) = try plannedTargetURL(meta: meta, archiveBaseURL: archiveBaseURL)

        do {
            try FileManager.default.createDirectory(at: targetDir, withIntermediateDirectories: true)
        } catch {
            throw FileOpsError.cannotCreateDir(targetDir)
        }

        var finalURL = baseCandidate

        if FileManager.default.fileExists(atPath: finalURL.path) {
            switch conflictPolicy {
            case .ask:
                // Signalisiere dem Aufrufer, dass er fragen soll
                throw FileOpsError.nameConflict(finalURL)

            case .autoSuffix:
                var i = 2
                while FileManager.default.fileExists(atPath: finalURL.path) {
                    finalURL = targetDir.appendingPathComponent("\(finalURL.deletingPathExtension().lastPathComponent) (\(i)).pdf")
                    i += 1
                }

            case .overwrite:
                // vorhandene Datei löschen
                try? FileManager.default.removeItem(at: finalURL)
            }
        }

        switch mode {
        case .move:
            do {
                try FileManager.default.moveItem(at: item.fileURL, to: finalURL)
            } catch {
                throw FileOpsError.moveFailed(error)
            }
            return PlacementResult(sourceURL: item.fileURL, finalURL: finalURL, wasCopied: false)

        case .copy(let deleteOriginal):
            do {
                try FileManager.default.copyItem(at: item.fileURL, to: finalURL)
            } catch {
                throw FileOpsError.copyFailed(error)
            }
            if deleteOriginal {
                do {
                    try FileManager.default.removeItem(at: item.fileURL)
                } catch {
                    throw FileOpsError.deleteOriginalFailed(error)
                }
            }
            return PlacementResult(sourceURL: item.fileURL, finalURL: finalURL, wasCopied: true)
        }
    }

    // Helpers
    private static func safeFileName(_ s: String) -> String { sanitize(s, allowSpaces: true) }
    private static func safeFolderName(_ s: String) -> String { sanitize(s, allowSpaces: true) }
    private static func sanitize(_ s: String, allowSpaces: Bool) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        var out = s.components(separatedBy: invalid).joined(separator: "_")
        if !allowSpaces { out = out.replacingOccurrences(of: " ", with: "_") }
        out = out.trimmingCharacters(in: .whitespacesAndNewlines)
        return out.isEmpty ? "Unbenannt" : out
    }
}
