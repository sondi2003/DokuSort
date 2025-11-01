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

    init(url: URL, fileSize: Int64?) {
        // WICHTIG: URL sofort normalisieren für konsistente Zuordnung
        let normalizedURL = url.normalizedFileURL

        // WICHTIG: Stabile ID basierend auf normalisierter URL generieren
        // Damit das gleiche Dokument immer die gleiche ID behält, auch nach Store-Scans
        self.id = Self.stableID(for: normalizedURL)
        self.fileName = normalizedURL.lastPathComponent
        self.fileURL = normalizedURL  // Gespeichert wird die normalisierte URL
        self.fileSize = fileSize
        self.addedAt = Date()
    }

    /// Generiert eine stabile UUID basierend auf dem normalisierten Dateipfad.
    /// Stellt sicher, dass das gleiche Dokument immer die gleiche ID hat.
    private static func stableID(for url: URL) -> UUID {
        // UUID v5: deterministisch basierend auf einem Namespace + Name
        let namespace = UUID(uuidString: "A7B3C5D9-1234-5678-9ABC-DEF012345678")!
        let path = url.normalizedFilePath
        return uuid(namespace: namespace, name: path)
    }

    /// Generiert eine UUID v5 (deterministisch) aus Namespace und Name
    private static func uuid(namespace: UUID, name: String) -> UUID {
        var data = Data()
        withUnsafeBytes(of: namespace.uuid) { data.append(contentsOf: $0) }
        data.append(name.data(using: .utf8)!)

        // SHA1-Hash für UUID v5
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA1($0.baseAddress, CC_LONG(data.count), &hash)
        }

        // UUID v5: Version-Bits auf 0101 (5) setzen
        hash[6] = (hash[6] & 0x0F) | 0x50
        // Variant-Bits auf 10xx setzen (RFC 4122)
        hash[8] = (hash[8] & 0x3F) | 0x80

        // UUID konstruieren
        let uuid = (
            hash[0], hash[1], hash[2], hash[3],
            hash[4], hash[5], hash[6], hash[7],
            hash[8], hash[9], hash[10], hash[11],
            hash[12], hash[13], hash[14], hash[15]
        )
        return UUID(uuid: uuid)
    }
}
