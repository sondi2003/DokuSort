//
//  DocumentStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import UniformTypeIdentifiers
import Combine
import Dispatch
import SwiftUI

// Hilfsklasse für sicheres Monitoring ohne MainActor-Probleme im deinit
private final class FolderMonitor {
    private let source: DispatchSourceFileSystemObject
    private let fd: CInt
    private let url: URL
    
    // Callback muss thread-safe sein oder auf MainActor dispatched werden
    init?(url: URL, queue: DispatchQueue, eventHandler: @escaping () -> Void) {
        let fd = open(url.path, O_EVTONLY)
        guard fd != -1 else { return nil }
        
        self.url = url
        self.fd = fd
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete],
            queue: queue
        )
        
        source.setEventHandler(handler: eventHandler)
        
        // Cleanup beim Abbrechen
        source.setCancelHandler {
            close(fd)
        }
        
        self.source = source
        source.resume()
    }
    
    deinit {
        source.cancel()
    }
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var items: [DocumentItem] = []

    // Wir halten nur noch eine Referenz auf den Monitor.
    // Wenn DocumentStore stirbt, stirbt auch monitor und räumt auf.
    private var folderMonitor: FolderMonitor?
    private var monitorSecurityScopeURL: URL? // URL die wir "accessen"
    
    private let monitorQueue = DispatchQueue(label: "ch.rulab.DokuSort.DocumentStore.monitor", qos: .utility)

    // MARK: - CRUD Operations
    
    func update(_ item: DocumentItem) {
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
    }
    
    func delete(_ item: DocumentItem) {
        try? FileManager.default.removeItem(at: item.fileURL)
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items.remove(at: index)
        }
    }
    
    func clear() {
        items = []
    }

    // MARK: - File Monitoring & Scanning

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

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

    func scanSourceFolder(_ source: URL?) {
        guard let source = source?.normalizedFileURL else { self.items = []; return }
        var tmp: [DocumentItem] = []
        if let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey, .fileSizeKey, .contentTypeKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) {
            for case let url as URL in enumerator {
                if url.deletingLastPathComponent() != source { continue }
                if url.pathExtension.lowercased() != "pdf" { continue }
                let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).map { Int64($0) }
                tmp.append(DocumentItem(url: url, fileSize: size))
            }
        }
        tmp.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        self.items = tmp
    }

    func startMonitoring(sourceURL: URL?) {
        // Altes Monitoring stoppen
        folderMonitor = nil
        if let oldUrl = monitorSecurityScopeURL {
            oldUrl.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
        }

        guard let sourceURL else { return }
        let normalized = sourceURL.normalizedFileURL
        
        // Security Scope öffnen
        let didAccess = normalized.startAccessingSecurityScopedResource()
        if didAccess {
            monitorSecurityScopeURL = normalized
        }

        // Neuen Monitor erstellen
        // Der Handler springt zurück auf den MainActor für den Rescan
        self.folderMonitor = FolderMonitor(url: normalized, queue: monitorQueue) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.scanSourceFolder(normalized)
            }
        }
        
        if self.folderMonitor == nil && didAccess {
            // Falls Monitor-Erstellung fehlschlug (z.B. open failed), Scope wieder schließen
            normalized.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
            print("⚠️ [DocumentStore] Monitoring konnte nicht gestartet werden.")
        }
    }
    
    func stopMonitoring() {
        folderMonitor = nil
        if let url = monitorSecurityScopeURL {
            url.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
        }
    }

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
    
    deinit {
        // Hier müssen wir nichts mehr tun, da folderMonitor automatisch deinitialisiert wird
        // und monitorSecurityScopeURL keinen manuellen clean im deinit erzwingt (URL deinit reicht nicht,
        // aber stopAccessing... im deinit auf MainActor ist eh verboten.
        // Best Practice: stopMonitoring() sollte beim Schließen der View/App aufgerufen werden.)
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
