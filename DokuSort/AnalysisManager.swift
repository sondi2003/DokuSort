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
    @Published private(set) var analyzed: Set<URL> = []

    func markAnalyzed(_ url: URL) {
        analyzed.insert(url)
    }

    func reset() {
        analyzed.removeAll()
    }

    func progress(total: Int) -> Double {
        guard total > 0 else { return 0 }
        return Double(analyzed.count) / Double(total)
    }
}

extension Notification.Name {
    static let analysisDidFinish = Notification.Name("DokuSort.analysisDidFinish")
}
