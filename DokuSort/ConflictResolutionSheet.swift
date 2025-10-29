//
//  ConflictResolutionSheet.swift
//  DokuSort
//
//  Created by Richard Sonderegger on 29.10.2025.
//

import SwiftUI

struct ConflictResolutionSheet: View {
    let conflictedURL: URL
    let onChoose: (ConflictPolicy?) -> Void   // nil = Abbrechen

    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                Text("Datei existiert bereits")
                    .font(.title3).bold()
            }

            Text(conflictedURL.lastPathComponent)
                .font(.callout)
                .foregroundStyle(.secondary)

            Text("Wie möchtest du fortfahren?")
                .padding(.top, 4)

            HStack {
                Button {
                    onChoose(.overwrite)
                } label: {
                    Label("Überschreiben", systemImage: "trash.fill")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    onChoose(.autoSuffix)
                } label: {
                    Label("Auto-Suffix", systemImage: "plus.square.on.square")
                }

                Button(role: .cancel) {
                    onChoose(nil)
                } label: {
                    Text("Abbrechen")
                }
            }
        }
        .padding(20)
        .frame(minWidth: 420)
    }
}
