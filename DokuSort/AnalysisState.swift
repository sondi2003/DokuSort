//
//  AnalysisState.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

struct AnalysisState: Codable, Equatable {
    enum Status: String, Codable {
        case pending
        case analyzed
        case failed
    }

    var status: Status
    var confidence: Double   // 0.0 ... 1.0
    var korrespondent: String?
    var dokumenttyp: String?
    var datum: Date?
}
