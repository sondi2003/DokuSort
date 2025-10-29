//
//  LoginItemManager.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import ServiceManagement

/// Manager zum Aktivieren/Prüfen des Login-Items.
enum LoginItemManager {
    /// Exakt den Bundle Identifier deines Login-Item-Targets einsetzen!
    private static let helperIdentifier = "ch.sondinetwork.dokusort.loginitem"

    /// Aktiviert das Login-Item, falls noch nicht aktiv.
    static func ensureEnabled() {
        let service = SMAppService.loginItem(identifier: helperIdentifier)
        do {
            if service.status != .enabled {
                try service.register()
                NSLog("LoginItemManager: Login-Item registriert.")
            } else {
                // bereits aktiv – nichts tun
            }
        } catch {
            NSLog("LoginItemManager: Registrieren fehlgeschlagen: \(error.localizedDescription)")
        }
    }

    /// Optional: explizit deaktivieren.
    static func disable() {
        let service = SMAppService.loginItem(identifier: helperIdentifier)
        do {
            if service.status == .enabled {
                try service.unregister()
                NSLog("LoginItemManager: Login-Item deaktiviert.")
            }
        } catch {
            NSLog("LoginItemManager: Unregister fehlgeschlagen: \(error.localizedDescription)")
        }
    }
}
