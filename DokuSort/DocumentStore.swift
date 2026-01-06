//
//  DocumentStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import PDFKit
import Combine
import Dispatch
import SwiftUI
import UniformTypeIdentifiers // <--- Dieser Import fehlte

// Hilfsklasse für sicheres Monitoring
private final class FolderMonitor {
    private let source: DispatchSourceFileSystemObject
    private let fd: CInt
    private let url: URL
    
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
        source.setCancelHandler { close(fd) }
        self.source = source
        source.resume()
    }
    deinit { source.cancel() }
}

@MainActor
final class DocumentStore: ObservableObject {
    @Published private(set) var items: [DocumentItem] = []
    
    private var folderMonitor: FolderMonitor?
    private var monitorSecurityScopeURL: URL?
    private let monitorQueue = DispatchQueue(label: "ch.rulab.DokuSort.DocumentStore.monitor", qos: .utility)

    private var docsDir: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }
    
    // MARK: - PDF Metadata Operations
    
    // Eigener Key für den extrahierten Text (unsichtbar für normale Viewer)
    private let customTextKey = "ch.rulab.dokusort.extractedText"

    /// Schreibt Metadaten direkt in die PDF-Datei
    private func saveMetadataToPDF(item: DocumentItem) {
        guard let pdf = PDFDocument(url: item.fileURL) else {
            print("⚠️ Konnte PDF für Metadaten-Update nicht öffnen: \(item.fileURL)")
            return
        }
        
        // Bestehende Attribute kopieren oder neu anlegen
        var attrs = pdf.documentAttributes ?? [:]
        
        // 1. Standard-Felder befüllen (Sichtbar im Finder/Preview)
        attrs[PDFDocumentAttribute.authorAttribute] = item.correspondent
        attrs[PDFDocumentAttribute.creationDateAttribute] = item.date
        attrs[PDFDocumentAttribute.keywordsAttribute] = item.tags // Array [String] wird von PDFKit unterstützt
        
        // 2. Extrahierter Text als Custom Field (Unsichtbar, aber persistent)
        if let text = item.extractedText {
            attrs[AnyHashable(customTextKey)] = text
        }
        
        pdf.documentAttributes = attrs
        
        // 3. Speichern (überschreibt die Datei)
        if !pdf.write(to: item.fileURL) {
            print("⚠️ Fehler beim Schreiben der PDF-Metadaten")
        } else {
            print("✅ Metadaten in PDF gespeichert: \(item.fileName)")
        }
    }
    
    /// Liest Metadaten aus der PDF-Datei
    private func loadMetadataFromPDF(url: URL) -> (date: Date?, correspondent: String?, tags: [String]?, text: String?) {
        guard let pdf = PDFDocument(url: url), let attrs = pdf.documentAttributes else {
            return (nil, nil, nil, nil)
        }
        
        let date = attrs[PDFDocumentAttribute.creationDateAttribute] as? Date
        let correspondent = attrs[PDFDocumentAttribute.authorAttribute] as? String
        let tags = attrs[PDFDocumentAttribute.keywordsAttribute] as? [String]
        let text = attrs[AnyHashable(customTextKey)] as? String
        
        return (date, correspondent, tags, text)
    }

    // MARK: - CRUD Operations
    
    func update(_ item: DocumentItem) {
        // 1. Memory Update
        if let index = items.firstIndex(where: { $0.id == item.id }) {
            items[index] = item
        }
        
        // 2. Disk Persistence (Direkt ins PDF)
        saveMetadataToPDF(item: item)
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

    // MARK: - Scanning & Loading

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
                var item = DocumentItem(url: url, fileSize: size)
                
                // Metadaten direkt aus dem PDF laden
                let meta = loadMetadataFromPDF(url: url)
                if let d = meta.date { item.date = d }
                if let c = meta.correspondent { item.correspondent = c }
                if let t = meta.tags { item.tags = t }
                if let txt = meta.text { item.extractedText = txt }
                
                tmp.append(item)
            }
        }
        tmp.sort { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        self.items = tmp
    }
    
    func reloadFromDisk() {
        scanSourceFolder(docsDir)
    }

    // MARK: - Monitoring

    func startMonitoring(sourceURL: URL?) {
        folderMonitor = nil
        if let oldUrl = monitorSecurityScopeURL {
            oldUrl.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
        }

        guard let sourceURL else { return }
        let normalized = sourceURL.normalizedFileURL
        
        let didAccess = normalized.startAccessingSecurityScopedResource()
        if didAccess { monitorSecurityScopeURL = normalized }

        self.folderMonitor = FolderMonitor(url: normalized, queue: monitorQueue) { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.scanSourceFolder(normalized)
            }
        }
        
        if self.folderMonitor == nil && didAccess {
            normalized.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
        }
    }
    
    func stopMonitoring() {
        folderMonitor = nil
        if let url = monitorSecurityScopeURL {
            url.stopAccessingSecurityScopedResource()
            monitorSecurityScopeURL = nil
        }
    }
    
    // MARK: - Import Helpers

    func importFiles(urls: [URL]) async throws {
        for src in urls {
            guard await src.startAccessingSecurityScopedResourceIfNeeded() else { continue }
            defer { src.stopAccessingSecurityScopedResourceIfNeeded() }

            if let type = try? src.resourceValues(forKeys: [.contentTypeKey]).contentType,
               type.conforms(to: .pdf) == false { continue }

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
            candidate = base.appendingPathComponent("\(name) (\(i)).\(ext)")
            i += 1
        }
        return candidate
    }
}

private extension URL {
    func startAccessingSecurityScopedResourceIfNeeded() async -> Bool {
        if isFileURL { return startAccessingSecurityScopedResource() }
        return true
    }
    func stopAccessingSecurityScopedResourceIfNeeded() {
        if isFileURL { stopAccessingSecurityScopedResource() }
    }
}
