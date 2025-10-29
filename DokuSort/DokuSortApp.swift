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
    @StateObject private var analysis = AnalysisManager()   // bleibt

    var body: some Scene {
        WindowGroup {
            MainDashboardView()              // 👈 jetzt Dashboard statt ContentView
                .environmentObject(store)
                .environmentObject(settings)
                .environmentObject(catalog)
                .environmentObject(analysis)
        }
    }
}
