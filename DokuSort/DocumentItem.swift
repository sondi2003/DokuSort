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
    let fileURL: URL
    let fileSize: Int64?
    let addedAt: Date

    init(url: URL, fileSize: Int64?) {
        self.id = UUID()
        self.fileName = url.lastPathComponent
        self.fileURL = url
        self.fileSize = fileSize
        self.addedAt = Date()
    }
}
