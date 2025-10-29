//
//  WindowManaager.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import AppKit

/// Verwaltet das Hauptfenster der App.
/// Stellt sicher, dass es bei Bedarf wieder angezeigt wird.
final class WindowManager {

    static let shared = WindowManager()
    private init() {}

    private var mainWindow: NSWindow?

    /// Registriert das Hauptfenster beim ersten Erscheinen.
    func registerMainWindow(_ window: NSWindow?) {
        guard let window else { return }
        self.mainWindow = window
    }

    /// Zeigt das Hauptfenster an oder bringt es nach vorn.
    func showMainWindow() {
        guard let window = mainWindow else {
            // Falls wir es noch nicht registriert haben, versuchen wir das aktive Fenster zu holen
            if let keyWindow = NSApp.windows.first {
                keyWindow.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            return
        }

        if window.isMiniaturized {
            window.deminiaturize(nil)
        }

        if !window.isVisible {
            window.makeKeyAndOrderFront(nil)
        }

        NSApp.activate(ignoringOtherApps: true)
    }
}
