//
//  UndoStore.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import Combine   // WICHTIG: für ObservableObject/@Published

@MainActor
final class UndoStore: ObservableObject {
    static let shared = UndoStore()

    struct Action: Identifiable, Equatable {
        let id = UUID()
        let movedFrom: URL
        let movedTo: URL
    }

    @Published private(set) var lastAction: Action?

    func registerMove(from: URL, to: URL) {
        lastAction = Action(movedFrom: from, movedTo: to)
    }

    func undoLastMove() throws {
        guard let action = lastAction else { return }

        var backTarget = action.movedFrom
        if FileManager.default.fileExists(atPath: backTarget.path) {
            // " (zurueck)" anhaengen, wenn Ursprungsname belegt ist
            let base = backTarget.deletingPathExtension()
            let ext = backTarget.pathExtension
            let newName = base.lastPathComponent + " (zurueck)"
            backTarget = base.deletingLastPathComponent().appendingPathComponent(newName).appendingPathExtension(ext)
        }

        try FileManager.default.moveItem(at: action.movedTo, to: backTarget)
        lastAction = nil
    }
}
