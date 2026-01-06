//
//  AutoCompleteTextField.swift
//  DokuSort
//
//  Created by DokuSort AI on 06.01.2026.
//

import SwiftUI

struct AutoCompleteTextField: View {
    let title: String
    @Binding var text: String
    let suggestions: [String]
    
    @State private var isFocused: Bool = false
    @State private var showList: Bool = false
    
    // Filtert die Vorschläge basierend auf der Eingabe
    var filteredSuggestions: [String] {
        if text.isEmpty { return [] }
        return suggestions.filter {
            $0.localizedCaseInsensitiveContains(text) &&
            $0.localizedCaseInsensitiveCompare(text) != .orderedSame
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            TextField(title, text: $text, onEditingChanged: { editing in
                isFocused = editing
                showList = editing
            })
            .textFieldStyle(RoundedBorderTextFieldStyle())
            .onChange(of: text) { _ in
                showList = true
            }
            .overlay(alignment: .topLeading) {
                // Das Dropdown-Menü
                if showList && isFocused && !filteredSuggestions.isEmpty {
                    VStack(spacing: 0) {
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(filteredSuggestions.prefix(5), id: \.self) { suggestion in
                                    Text(suggestion)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 6)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .contentShape(Rectangle())
                                        .onTapGesture {
                                            self.text = suggestion
                                            self.showList = false
                                            // Fokus könnte hier theoretisch entfernt werden,
                                            // aber oft will man weitertippen (z.B. Tab).
                                        }
                                        // Hover-Effekt für Maus-Bedienung
                                        .onHover { isHovered in
                                            if isHovered { NSCursor.pointingHand.push() }
                                            else { NSCursor.pop() }
                                        }
                                }
                            }
                        }
                    }
                    .frame(height: min(CGFloat(filteredSuggestions.prefix(5).count * 30), 150))
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(5)
                    .overlay(RoundedRectangle(cornerRadius: 5).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                    .shadow(radius: 4)
                    .offset(y: 25) // Verschiebt das Menü unter das Textfeld
                }
            }
            // Z-Index ist wichtig, damit das Menü über anderen Formular-Elementen schwebt
            .zIndex(showList && !filteredSuggestions.isEmpty ? 100 : 0)
        }
    }
}
