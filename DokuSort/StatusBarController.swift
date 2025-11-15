//
//  StatusBarController.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import AppKit
import Combine

/// Steuert das Menüleisten-Icon (Status Bar Item) für DokuSort.
final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()

    // schwache Referenzen auf zentrale Stores (werden vom App-Lifecycle gehalten)
    private weak var store: DocumentStore?
    private weak var settings: SettingsStore?
    private weak var analysis: AnalysisManager?

    private var cancellables: Set<AnyCancellable> = []

    init(store: DocumentStore,
         settings: SettingsStore,
         analysis: AnalysisManager) {
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        self.store = store
        self.settings = settings
        self.analysis = analysis
        super.init()
        configureStatusItem()
        buildMenu()
        bindObservers(store: store, settings: settings, analysis: analysis)
        updateMenuDynamicParts()
    }

    deinit {
        NSStatusBar.system.removeStatusItem(statusItem)
        cancellables.removeAll()
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
            button.toolTip = "DokuSort Status"
        }
        statusItem.menu = menu
    }

    private enum Tags: Int {
        case header = 10
        case progress = 11
        case sourcePath = 12
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

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Beenden", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func bindObservers(store: DocumentStore, settings: SettingsStore, analysis: AnalysisManager) {
        store.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuDynamicParts() }
            .store(in: &cancellables)

        settings.$sourceBaseURL
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuDynamicParts() }
            .store(in: &cancellables)

        analysis.objectWillChange
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuDynamicParts() }
            .store(in: &cancellables)
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
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        // Bringt App in den Vordergrund und zeigt das Hauptfenster
        DispatchQueue.main.async {
            WindowManager.shared.showMainWindow()
        }
    }

    @objc private func scanNow() {
        guard let store, let settings, let analysis else { return }
        store.scanSourceFolder(settings.sourceBaseURL)
        let urls = store.items.map { $0.fileURL }
        analysis.preloadStates(for: urls)
        analysis.refreshFromPersistence(for: urls)
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
