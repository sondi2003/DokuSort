//
//  AnalysisState.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation

// Notifications, die wir projektweit nutzen
extension Notification.Name {
    static let analysisDidFinish  = Notification.Name("DokuSort.analysisDidFinish")
    static let analysisDidFail    = Notification.Name("DokuSort.analysisDidFail")
    static let documentDidArchive = Notification.Name("DokuSort.documentDidArchive")
}

/// Persistierbarer Analysezustand pro Datei.
struct AnalysisState: Codable {
    enum Status: String, Codable { case analyzed, failed }
    var status: Status
    var confidence: Double

    var korrespondent: String?
    var dokumenttyp: String?
    var datum: Date?

    // Datei-Facts, damit wir Erkennung auf Gültigkeit prüfen können
    var fileSize: Int64?
    var fileModDate: Date?

    init(status: Status,
         confidence: Double,
         korrespondent: String? = nil,
         dokumenttyp: String? = nil,
         datum: Date? = nil,
         fileSize: Int64? = nil,
         fileModDate: Date? = nil) {
        self.status = status
        self.confidence = confidence
        self.korrespondent = korrespondent
        self.dokumenttyp = dokumenttyp
        self.datum = datum
        self.fileSize = fileSize
        self.fileModDate = fileModDate
    }
}
