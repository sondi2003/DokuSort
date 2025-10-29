//
//  DokuSortApp.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

@main
struct DokuSortApp: App {
    @StateObject private var store = DocumentStore()
    @StateObject private var settings = SettingsStore()
    @StateObject private var catalog = CatalogStore()
    @StateObject private var analysis = AnalysisManager()
    @StateObject private var watcher = SourceWatcher()   // << neu

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis)
                .onAppear {
                    // Beim ersten Start: wenn Quelle gesetzt, sofort Watcher starten + initial scannen
                    watcher.startWatching(url: settings.sourceBaseURL)
                    if settings.sourceBaseURL != nil && store.items.isEmpty {
                        store.scanSourceFolder(settings.sourceBaseURL)
                    }
                }
                // Wenn sich die Quelle ändert → Watcher neu starten und neu scannen
                .onChange(of: settings.sourceBaseURL) { _, newValue in
                    watcher.startWatching(url: newValue)
                    store.scanSourceFolder(newValue)
                    analysis.reset()
                }
        }
    }
}
