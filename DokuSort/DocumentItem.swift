//
//  DocumentItem.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import CommonCrypto

struct DocumentItem: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let fileURL: URL  // Immer normalisiert
    let fileSize: Int64?
    let addedAt: Date

    // NEU: Metadaten Felder
    var date: Date
    var correspondent: String
    var tags: [String]
    var extractedText: String?

    // Initializer für neue Dateien
    init(url: URL, fileSize: Int64?) {
        let normalizedURL = url.normalizedFileURL
        self.id = Self.stableID(for: normalizedURL)
        self.fileName = normalizedURL.lastPathComponent
        self.fileURL = normalizedURL
        self.fileSize = fileSize
        self.addedAt = Date()
        
        // Standardwerte
        self.date = Date()
        self.correspondent = ""
        self.tags = []
        self.extractedText = nil
    }

    // Initializer für Updates (alle Felder explizit setzen)
    init(id: UUID, fileName: String, fileURL: URL, fileSize: Int64?, addedAt: Date, date: Date, correspondent: String, tags: [String], extractedText: String?) {
        self.id = id
        self.fileName = fileName
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.addedAt = addedAt
        self.date = date
        self.correspondent = correspondent
        self.tags = tags
        self.extractedText = extractedText
    }

    /// Generiert eine stabile UUID basierend auf dem normalisierten Dateipfad.
    private static func stableID(for url: URL) -> UUID {
        let namespace = UUID(uuidString: "A7B3C5D9-1234-5678-9ABC-DEF012345678")!
        let path = url.normalizedFilePath
        return uuid(namespace: namespace, name: path)
    }

    private static func uuid(namespace: UUID, name: String) -> UUID {
        var data = Data()
        withUnsafeBytes(of: namespace.uuid) { data.append(contentsOf: $0) }
        data.append(name.data(using: .utf8)!)

        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &hash)
        }

        hash[6] = (hash[6] & 0x0F) | 0x50
        hash[8] = (hash[8] & 0x3F) | 0x80

        let uuid = (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        )
        return UUID(uuid: uuid)
    }
}
