//
//  DocumentItem.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

struct DocumentItem: Identifiable, Hashable {
    let id: UUID
    let fileName: String
    let fileURL: URL  // Immer normalisiert
    let fileSize: Int64?
    let addedAt: Date

    init(url: URL, fileSize: Int64?) {
        // WICHTIG: URL sofort normalisieren für konsistente Zuordnung
        let normalizedURL = url.normalizedFileURL

        self.id = UUID()
        self.fileName = normalizedURL.lastPathComponent
        self.fileURL = normalizedURL  // Gespeichert wird die normalisierte URL
        self.fileSize = fileSize
        self.addedAt = Date()
    }
}
