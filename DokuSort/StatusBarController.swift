//
//  StatusBarController.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import AppKit

/// Steuert das Menüleisten-Icon (Status Bar Item) für DokuSort.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    // schwache Referenzen auf zentrale Stores (werden vom App-Lifecycle gehalten)
    private weak var store: DocumentStore?
    private weak var settings: SettingsStore?
    private weak var analysis: AnalysisManager?
    private weak var watcher: SourceWatcher?

    // Zustand
    private var isPaused = false

    init(store: DocumentStore,
         settings: SettingsStore,
         analysis: AnalysisManager,
         watcher: SourceWatcher) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.settings = settings
        self.analysis = analysis
        self.watcher = watcher
        super.init()
        configureStatusItem()
        buildMenu()
        updateMenuDynamicParts()
        // Auf Analyse-/Quellordner-Events reagieren, um das Menü aktuell zu halten
        NotificationCenter.default.addObserver(self, selector: #selector(handleAnalysisChanged(_:)),
                                               name: .analysisDidFinish, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(handleSourceChanged),
                                               name: .sourceFolderDidChange, object: nil)
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
        NotificationCenter.default.removeObserver(self)
    }

    // MARK: - Setup

    private func configureStatusItem() {
        if let button = statusItem.button {
            // SF Symbol als Icon
            if let img = NSImage(systemSymbolName: "doc.text.magnifyingglass",
                                 accessibilityDescription: "DokuSort") {
                img.isTemplate = true // passt sich an Hell/Dunkel an
                button.image = img
            } else {
                button.title = "DokuSort"
            }
            button.toolTip = "DokuSort – Hintergrundanalyse"
        }
        statusItem.menu = menu
    }

    private enum Tags: Int {
        case header = 10
        case progress = 11
        case sourcePath = 12
        case pauseResume = 20
    }

    private func buildMenu() {
        menu.autoenablesItems = false
        menu.removeAllItems()

        // Header
        let header = NSMenuItem(title: "DokuSort", action: nil, keyEquivalent: "")
        header.tag = Tags.header.rawValue
        header.isEnabled = false
        menu.addItem(header)

        // Fortschritt
        let progressItem = NSMenuItem(title: "Fortschritt: –/–", action: nil, keyEquivalent: "")
        progressItem.tag = Tags.progress.rawValue
        progressItem.isEnabled = false
        menu.addItem(progressItem)

        // Quelle
        let sourceItem = NSMenuItem(title: "Quelle: (nicht gesetzt)", action: nil, keyEquivalent: "")
        sourceItem.tag = Tags.sourcePath.rawValue
        sourceItem.isEnabled = false
        menu.addItem(sourceItem)

        menu.addItem(.separator())

        // Aktionen
        let openMain = NSMenuItem(title: "Hauptfenster öffnen", action: #selector(openMainWindow), keyEquivalent: "o")
        openMain.target = self
        menu.addItem(openMain)

        let rescan = NSMenuItem(title: "Quelle scannen", action: #selector(scanNow), keyEquivalent: "r")
        rescan.target = self
        menu.addItem(rescan)

        let pauseResume = NSMenuItem(title: "Beobachtung pausieren", action: #selector(togglePause), keyEquivalent: "p")
        pauseResume.target = self
        pauseResume.tag = Tags.pauseResume.rawValue
        menu.addItem(pauseResume)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    // MARK: - Dynamic Updates

    @objc private func handleAnalysisChanged(_ note: Notification) {
        updateMenuDynamicParts()
    }

    @objc private func handleSourceChanged() {
        updateMenuDynamicParts()
    }

    private func updateMenuDynamicParts() {
        guard let analysis, let store, let settings else { return }

        let analyzed = analysis.analyzedCount
        let total = store.items.count

        if let progressItem = menu.item(withTag: Tags.progress.rawValue) {
            progressItem.title = "Fortschritt: \(analyzed)/\(total)"
        }

        if let sourceItem = menu.item(withTag: Tags.sourcePath.rawValue) {
            if let src = settings.sourceBaseURL {
                sourceItem.title = "Quelle: " + src.path
            } else {
                sourceItem.title = "Quelle: (nicht gesetzt)"
            }
        }

        if let pauseItem = menu.item(withTag: Tags.pauseResume.rawValue) {
            pauseItem.title = isPaused ? "Beobachtung fortsetzen" : "Beobachtung pausieren"
        }
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        // App in den Vordergrund bringen (öffnet/aktiviert das Hauptfenster)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func scanNow() {
        guard let store, let settings else { return }
        store.scanSourceFolder(settings.sourceBaseURL)
    }

    @objc private func togglePause() {
        guard let watcher, let settings else { return }
        if isPaused {
            watcher.startWatching(url: settings.sourceBaseURL)
            isPaused = false
        } else {
            watcher.stopWatching()
            isPaused = true
        }
        updateMenuDynamicParts()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
