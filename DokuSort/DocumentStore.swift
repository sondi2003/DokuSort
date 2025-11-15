//
//  DocumentStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import UniformTypeIdentifiers
import Combine

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var items: [DocumentItem] = []

    // App-Dokumente (nutzen wir weiterhin für evtl. manuelle Importe)
    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    // Bestehend: neu von App-Dokumenten laden (für Undo-Fälle okay)
    func reloadFromDisk() {
        var tmp: [DocumentItem] = []
        if let enumerator = FileManager.default.enumerator(
            at: docsDir,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles]
        ) {
            for case let url as URL in enumerator {
                guard url.pathExtension.lowercased() == "pdf" else { continue }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
                tmp.append(DocumentItem(url: url, fileSize: size))
            }
        }
        tmp.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        self.items = tmp
    }

    /// Entfernt alle geladenen Elemente, z. B. nach Quellenwechsel.
    func clear() {
        items = []
    }

    // NEU: Quelle scannen (alle PDFs im Quellordner, Ebene 1)
    func scanSourceFolder(_ source: URL?) {
        guard let source = source?.normalizedFileURL else { self.items = []; return }
        var tmp: [DocumentItem] = []
        if let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator {
                // nur Top-Level
                if url.deletingLastPathComponent() != source { continue }
                if url.pathExtension.lowercased() != "pdf" { continue }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
                tmp.append(DocumentItem(url: url, fileSize: size))
            }
        }
        tmp.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        self.items = tmp
    }

    // Optional: manueller Import (lassen wir drin)
    func importFiles(urls: [URL]) async throws {
        for src in urls {
            guard await src.startAccessingSecurityScopedResourceIfNeeded() else { continue }
            defer { src.stopAccessingSecurityScopedResourceIfNeeded() }

            if let type = try? src.resourceValues(forKeys: [.contentTypeKey]).contentType,
               type.conforms(to: .pdf) == false {
                continue
            }

            let dest = uniqueDestination(for: src.lastPathComponent)
            try FileManager.default.copyItem(at: src, to: dest)
        }
        reloadFromDisk()
    }

    private func uniqueDestination(for proposedName: String) -> URL {
        let base = docsDir
        var candidate = base.appendingPathComponent(proposedName)
        let name = (proposedName as NSString).deletingPathExtension
        let ext = (proposedName as NSString).pathExtension

        var i = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let newName = "\(name) (\(i)).\(ext)"
            candidate = base.appendingPathComponent(newName)
            i += 1
        }
        return candidate
    }

    func delete(_ item: DocumentItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        // Beim Löschen aus Quelle danach Quelle neu scannen (der Aufrufer weiss, ob Quelle aktiv ist)
    }
}

// Security-Scoped Helpers
private extension URL {
    func startAccessingSecurityScopedResourceIfNeeded() async -> Bool {
        if isFileURL { return startAccessingSecurityScopedResource() }
        return true
    }
    func stopAccessingSecurityScopedResourceIfNeeded() {
        if isFileURL { stopAccessingSecurityScopedResource() }
    }
}
