//
//  DokuSortApp.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

@main
struct DokuSortApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var store = DocumentStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var catalog = CatalogStore()
    @StateObject private var analysis = AnalysisManager()
    @StateObject private var watcher = SourceWatcher()

    @State private var statusBarController: StatusBarController?
    @State private var bgAnalyzer: BackgroundAnalyzer?

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis)
                .onAppear {
                    // Persistenz ist über Singleton geladen; AnalysisManager hat gebootstrapped.
                    // Watcher starten + initial scannen
                    watcher.startWatching(url: settings.sourceBaseURL)
                    if settings.sourceBaseURL != nil && store.items.isEmpty {
                        store.scanSourceFolder(settings.sourceBaseURL)
                    }
                    // Statusbar-Icon
                    if statusBarController == nil {
                        statusBarController = StatusBarController(store: store,
                                                                  settings: settings,
                                                                  analysis: analysis,
                                                                  watcher: watcher)
                    }
                    // Hauptfenster für WindowManager registrieren
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        WindowManager.shared.registerMainWindow(window)
                    }
                }
                .onChange(of: settings.sourceBaseURL) { _, newValue in
                    watcher.startWatching(url: newValue)
                    store.scanSourceFolder(newValue)
                    analysis.reset()
                }
        }
    }
}
