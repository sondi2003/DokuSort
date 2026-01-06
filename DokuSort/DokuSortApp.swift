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
        // 1. Das Hauptfenster
        WindowGroup {
            MainDashboardView()
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis) // Optional, falls noch genutzt
                .onAppear {
                    setupApp()
                }
                .onChange(of: settings.sourceBaseURL) { _, newValue in
                    rescan(newValue)
                }
        }
        .commands {
            // Fügt Standard-Sidebar-Befehle hinzu (Ansicht -> Seitenleiste ein/aus)
            SidebarCommands()
        }

        // 2. Das native Einstellungsfenster (CMD+,)
        Settings {
            SettingsView()
                .environmentObject(settings)
                .environmentObject(catalog)
        }
    }
    
    // MARK: - App Logic Helpers
    
    private func setupApp() {
        // Statusbar
        if statusBarController == nil {
            statusBarController = StatusBarController(
                store: store,
                settings: settings,
                analysis: analysis
            )
        }

        // Hauptfenster-Registrierung
        if let window = NSApp.keyWindow ?? NSApp.windows.first {
            WindowManager.shared.registerMainWindow(window)
        }

        // Initial Scan
        if didInitializeSourceScan == false {
            didInitializeSourceScan = true
            let sourceURL = settings.sourceBaseURL
            store.scanSourceFolder(sourceURL)
            store.startMonitoring(sourceURL: sourceURL)
            
            // Analysis-Preload (für alte Sidebar-Anzeige)
            let urls = store.items.map { $0.fileURL }
            analysis.preloadStates(for: urls)
            analysis.refreshFromPersistence(for: urls)
        }
    }
    
    private func rescan(_ url: URL?) {
        store.stopMonitoring()
        analysis.reset()
        store.scanSourceFolder(url)
        if let url {
            store.startMonitoring(sourceURL: url)
        }
        let urls = store.items.map { $0.fileURL }
        analysis.preloadStates(for: urls)
        analysis.refreshFromPersistence(for: urls)
    }
}
