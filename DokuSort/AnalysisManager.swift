//
//  AnalysisManager.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine

@MainActor
final class AnalysisManager: ObservableObject {
    // Datei-URL -> State
    @Published private(set) var states: [URL: AnalysisState] = [:]

    func markAnalyzed(url: URL, state: AnalysisState) {
        states[url] = state
    }

    func markFailed(url: URL) {
        states[url] = AnalysisState(status: .failed, confidence: 0.0, korrespondent: nil, dokumenttyp: nil, datum: nil)
    }

    func reset() {
        states.removeAll()
    }

    func state(for url: URL) -> AnalysisState? {
        states[url]
    }

    func isAnalyzed(_ url: URL) -> Bool {
        states[url]?.status == .analyzed
    }

    func progress(total: Int) -> Double {
        guard total > 0 else { return 0 }
        let done = states.values.filter { $0.status == .analyzed }.count
        return Double(done) / Double(total)
    }

    var analyzedCount: Int { states.values.filter { $0.status == .analyzed }.count }
}

extension Notification.Name {
    static let analysisDidFinish = Notification.Name("DokuSort.analysisDidFinish")
    static let analysisDidFail   = Notification.Name("DokuSort.analysisDidFail")
}
