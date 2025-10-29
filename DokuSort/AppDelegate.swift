//
//  AppDelegate.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// Beende die App NICHT, wenn alle Fenster zu sind.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    /// Klick auf das Dock-Icon oder „App erneut öffnen“ (kein Fenster sichtbar)?
    /// → Hauptfenster zeigen.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            WindowManager.shared.showMainWindow()
        }
        return true
    }
}
