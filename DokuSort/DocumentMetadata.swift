//
//  DocumentMetadata.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

struct DocumentMetadata: Hashable, Codable {
    var datum: Date
    var jahr: String {
        let y = Calendar.current.component(.year, from: datum)
        return String(y)
    }
    var korrespondent: String
    var dokumenttyp: String

    static func empty() -> DocumentMetadata {
        DocumentMetadata(datum: Date(), korrespondent: "", dokumenttyp: "")
    }
}
