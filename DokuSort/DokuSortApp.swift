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
    @StateObject private var catalog = CatalogStore()
    @StateObject private var settings = SettingsStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(catalog)
                .environmentObject(settings)
                .onAppear {
                    store.reloadFromDisk()
                }
        }
    }
}
