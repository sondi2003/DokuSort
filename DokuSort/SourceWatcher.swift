//
//  SourceWatcher.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import Foundation
import CoreServices
import Combine   // für ObservableObject

extension Notification.Name {
    /// Wird gepostet, wenn sich im Quellordner etwas ändert.
    static let sourceFolderDidChange = Notification.Name("DokuSort.sourceFolderDidChange")
}

/// Beobachtet Änderungen im Quellordner via FSEvents.
/// Läuft NICHT am Main-Actor; UI wird per Notification auf den Main-Thread informiert.
final class SourceWatcher: ObservableObject {
    private var streamRef: FSEventStreamRef?
    private var watchedPath: String?
    private var debounceWorkItem: DispatchWorkItem?

    /// Startet das Watching für den angegebenen Ordner.
    func startWatching(url: URL?) {
        stopWatching()
        guard let url = url?.normalizedFileURL else { return }
        let path = url.normalizedFilePath

        // FSEvents-Callback (Background-Queue)
        let callback: FSEventStreamCallback = { (_, clientCallBackInfo, _, _, _, _) in
            let watcher = Unmanaged<SourceWatcher>.fromOpaque(clientCallBackInfo!).takeUnretainedValue()
            watcher.handleEvents()
        }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            [path] as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5, // Latenz (Sekunden)
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents
                                     | kFSEventStreamCreateFlagUseCFTypes
                                     | kFSEventStreamCreateFlagNoDefer)
        ) else {
            print("SourceWatcher: Stream konnte nicht erstellt werden.")
            return
        }

        self.streamRef = stream
        self.watchedPath = path

        // Events auf eine Hintergrund-Queue liefern
        FSEventStreamSetDispatchQueue(stream, DispatchQueue.global(qos: .utility))
        FSEventStreamStart(stream)

        // Initiale Meldung direkt nach Start (praktisch beim App-Start)
        notifyChangeDebounced()
    }

    /// Stoppt das Watching.
    func stopWatching() {
        if let stream = streamRef {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
        streamRef = nil
        watchedPath = nil
        debounceWorkItem?.cancel()
        debounceWorkItem = nil
    }

    deinit {
        stopWatching()
    }

    // MARK: - Intern

    /// Wird aus dem FSEvents-Callback (Background-Queue) getriggert.
    private func handleEvents() {
        notifyChangeDebounced()
    }

    /// Fasst schnelle Event-Serien zusammen und postet einmalig eine Notification.
    private func notifyChangeDebounced() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self = self, self.watchedPath != nil else { return }
            // UI/SwiftUI hört auf diese Notification; immer auf dem Main-Thread posten
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .sourceFolderDidChange, object: nil)
            }
        }
        debounceWorkItem = work
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 0.35, execute: work)
    }
}
