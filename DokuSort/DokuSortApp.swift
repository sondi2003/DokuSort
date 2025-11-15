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

    @State private var statusBarController: StatusBarController?
    @State private var didInitializeSourceScan = false

    var body: some Scene {
        WindowGroup {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis)
                .onAppear {
                    // Statusbar-Icon initialisieren
                    if statusBarController == nil {
                        statusBarController = StatusBarController(
                            store: store,
                            settings: settings,
                            analysis: analysis
                        )
                    }

                    // Hauptfenster fuer "Hauptfenster oeffnen" registrieren
                    if let window = NSApp.keyWindow ?? NSApp.windows.first {
                        WindowManager.shared.registerMainWindow(window)
                    }

                    if didInitializeSourceScan == false {
                        didInitializeSourceScan = true
                        let sourceURL = settings.sourceBaseURL
                        store.scanSourceFolder(sourceURL)
                        store.startMonitoring(sourceURL: sourceURL)
                        let urls = store.items.map { $0.fileURL }
                        analysis.preloadStates(for: urls)
                        analysis.refreshFromPersistence(for: urls)
                    }
                }
                .onChange(of: settings.sourceBaseURL) { _, newValue in
                    store.stopMonitoring()
                    analysis.reset()
                    store.scanSourceFolder(newValue)
                    if let newValue {
                        store.startMonitoring(sourceURL: newValue)
                    }
                    let urls = store.items.map { $0.fileURL }
                    analysis.preloadStates(for: urls)
                    analysis.refreshFromPersistence(for: urls)
                }
        }
    }
}
