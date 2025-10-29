//
//  DokuSortApp.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

@main
struct DokuSortApp: App {
    // App-Delegate für Fenster-/Lebenszyklusverhalten
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store = DocumentStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var catalog = CatalogStore()
    @StateObject private var analysis = AnalysisManager()
    @StateObject private var watcher = SourceWatcher()

    // Retain der StatusBar-Instanz
    @State private var statusBarController: StatusBarController?

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis)
                .onAppear {
                    // Watcher starten (falls Quelle gewählt) + initial scannen
                    watcher.startWatching(url: settings.sourceBaseURL)
                    if settings.sourceBaseURL != nil && store.items.isEmpty {
                        store.scanSourceFolder(settings.sourceBaseURL)
                    }
                    // Statusbar-Icon initialisieren (einmalig)
                    if statusBarController == nil {
                        statusBarController = StatusBarController(
                            store: store,
                            settings: settings,
                            analysis: analysis,
                            watcher: watcher
                        )
                    }
                }
                // Quelle geändert? ⇒ Watcher neu starten + neu scannen + Fortschritt zurücksetzen
                .onChange(of: settings.sourceBaseURL) { _, newValue in
                    watcher.startWatching(url: newValue)
                    store.scanSourceFolder(newValue)
                    analysis.reset()
                }
                // Hauptfenster registrieren, damit es aus Menü/Dock sicher reaktiviert werden kann
                .onAppear {
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        WindowManager.shared.registerMainWindow(window)
                    }
                }
        }
    }
}
