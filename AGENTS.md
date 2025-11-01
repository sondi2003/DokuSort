# DokuSort Development Guidelines

## Entwicklungsumgebung

### Toolchain-Anforderungen
- **Xcode:** Version 26.x
- **SwiftUI:** Version 6.x
- **Deployment Target:** macOS 26 (Tahoe)
- **Swift:** Latest stable version compatible with Xcode 26.x

## macOS Tahoe Spezifikationen

### Platform Requirements
- **Minimum Version:** macOS 26.0
- **Target OS:** macOS Tahoe
- **Architecture:** Apple Silicon (arm64) & Intel (x86_64)

### Neueste macOS Tahoe Features
- Nutze moderne macOS 26 APIs und Frameworks
- Implementiere native Tahoe Design-Patterns
- Verwende neue System-Features wo sinnvoll
- Optimierung für Apple Silicon Performance

## SwiftUI 6.x Best Practices

### Moderne SwiftUI-Architektur
- **Observable Framework:** Verwende `@Observable` Makro anstelle von `@StateObject` und `@ObservableObject` wo möglich
- **Swift Concurrency:** Konsequente Nutzung von async/await und Structured Concurrency
- **@Environment:** Modernisierte Environment-Werte für Dependency Injection
- **View Modifiers:** Bevorzuge custom view modifiers für wiederverwendbare Komponenten

### State Management
- `@State` für view-lokale Zustände
- `@Observable` für shared state zwischen Views
- `@Environment` für App-weite Dependencies
- Minimiere `@Binding` durch direkte State-Propagation

### Performance-Optimierung
- Nutze SwiftUI 6.x View-Caching automatisch
- Vermeide unnötige View-Updates durch präzise State-Modellierung
- Verwende `@MainActor` für UI-Updates explizit
- Lazy Loading für große Datenmengen (Lists, ScrollViews)

### Layout & Navigation
- Nutze moderne Container-Views (Grid, Layout Protocol)
- NavigationStack und NavigationSplitView für Navigation
- Präferiere declarative Navigation über imperative
- Responsive Layouts für unterschiedliche Fenstergrößen

## Corporate Design Richtlinien

### Farbschema
- **Primärfarbe:** System Accent Color (anpassbar durch Benutzer)
- **Hintergrund:** System Background Colors (Light/Dark Mode Support)
- **Text:** System Label Colors mit semantischen Hierarchien
- **Statusfarben:**
  - Erfolg: System Green
  - Warnung: System Orange
  - Fehler: System Red
  - Information: System Blue

### Typografie
- **Systemschrift:** SF Pro (macOS Standard)
- **Hierarchie:**
  - Titel: `.largeTitle`, `.title`, `.title2`, `.title3`
  - Body: `.body`, `.callout`
  - Detail: `.caption`, `.caption2`
- **Lesbarkeit:** Dynamic Type Support, ausreichende Kontraste

### Spacing & Layout
- **Standard Padding:** 8pt, 12pt, 16pt, 20pt, 24pt
- **Sektions-Abstände:** 16pt - 24pt
- **Content Margins:** System Standard (respektiere Safe Areas)
- **Corner Radius:** 8pt - 12pt für Karten und Container

### UI-Komponenten
- **Native Controls:** Bevorzuge macOS native Steuerelemente
- **Buttons:**
  - Primäre Aktionen: `.buttonStyle(.borderedProminent)`
  - Sekundäre Aktionen: `.buttonStyle(.bordered)`
  - Tertiäre Aktionen: `.buttonStyle(.plain)` oder `.buttonStyle(.link)`
- **Forms:** Nutze `Form` und `Section` für Einstellungen
- **Listen:** Nutze `List` mit modernen Styles (`.listStyle(.sidebar)`, `.listStyle(.inset)`)

### Icons & Symbole
- **SF Symbols:** Ausschließliche Verwendung für Konsistenz
- **Icon-Größen:** Kontextabhängig (small: 12pt, medium: 16pt, large: 20pt+)
- **Multicolor:** Nutze Multicolor-Varianten für System-Features
- **Rendering Mode:** Template-Mode für anpassbare Farben

### Fenster & Chrome
- **Toolbar:** Native macOS Toolbar mit `ToolbarItemGroup`
- **Sidebar:** `NavigationSplitView` für Haupt-Navigation
- **Inspector:** Rechte Sidebar für Details/Metadaten
- **Full-Size Content:** Nutze `.windowStyle(.titleBar)` für moderne Ästhetik

## Architektur-Patterns

### MVVM Pattern
- **Models:** Reine Datenstrukturen (structs bevorzugt)
- **Views:** SwiftUI Views (dump, declarative)
- **ViewModels:** `@Observable` classes für Business Logic
- **Services:** Singleton oder Environment-injected für externe Abhängigkeiten

### Separation of Concerns
- UI-Code strikt getrennt von Business Logic
- Service-Layer für Netzwerk, File I/O, externe APIs
- Manager-Klassen für komplexe Geschäftslogik
- Utility-Extensions in separaten Dateien

### Dependency Injection
- Environment-basierte Injection für Views
- Protocol-oriented Design für Testbarkeit
- Mock-Implementierungen für Tests

## Code-Konventionen

### Swift Style Guide
- **Naming:** CamelCase für Types, lowerCamelCase für Variablen/Funktionen
- **Dokumentation:** DocC-kompatible Kommentare für öffentliche APIs
- **Access Control:** Explizite Access-Level (`private`, `fileprivate`, `internal`, `public`)
- **Extensions:** Logische Gruppierung von Funktionalität

### File Organization
```
DokuSort/
├── App/                 # App Entry Point, Main Views
├── Views/              # SwiftUI Views
├── ViewModels/         # Observable ViewModels
├── Models/             # Data Models
├── Services/           # External Services (OCR, Ollama, FileOps)
├── Managers/           # Business Logic Managers
├── Utilities/          # Helper Functions, Extensions
└── Resources/          # Assets, Localizations
```

### Code Quality
- **SwiftLint:** Einhaltung von Code-Standards
- **Code Reviews:** Alle Änderungen durch Review
- **Testing:** Unit Tests für Business Logic, UI Tests für kritische Flows
- **Documentation:** Inline-Dokumentation für komplexe Logik

## SwiftUI 6.x Specific Features

### Neueste APIs nutzen
- **@Previewable:** Für Preview-spezifische States
- **@Entry:** Für Environment-Values
- **#Preview:** Makro für moderne Previews
- **Scrolling Enhancements:** ScrollPosition, contentMargins
- **Animations:** Phase Animator, Keyframe Animator

### Accessibility
- **VoiceOver:** Vollständige Unterstützung mit `.accessibilityLabel()`, `.accessibilityHint()`
- **Dynamic Type:** Automatische Skalierung mit System Font Sizes
- **Keyboard Navigation:** Full Keyboard Access Support
- **Reduce Motion:** Respektiere Accessibility Settings

### Localization
- **String Catalogs:** Nutze Xcode 15+ String Catalogs
- **LocalizedStringKey:** Automatische Lokalisierung in SwiftUI
- **Formatierung:** Locale-aware Number/Date Formatting

## Performance Guidelines

### Memory Management
- Vermeide Retain Cycles durch `[weak self]` in Closures
- Nutze `@MainActor` für UI-Updates
- Lazy Loading für große Datenstrukturen
- Dispose Resources explizit (File Handles, Observers)

### Background Processing
- **Task Groups:** Für parallele asynchrone Operationen
- **Actor Isolation:** Für Thread-Safe Data Access
- **AsyncSequence:** Für Streams und kontinuierliche Daten

### File Operations
- Asynchrone File I/O für große Dateien
- Security-Scoped Bookmarks für persistente Ordnerzugriffe
- FileCoordinator für koordinierte Zugriffe
- Progress Reporting für lange Operationen

## Testing Strategy

### Unit Tests
- ViewModels und Business Logic vollständig testen
- Mock Services für externe Dependencies
- Edge Cases und Error Handling abdecken

### Integration Tests
- Service-Integration testen (OCR, Ollama)
- File Operations validieren
- End-to-End Workflows testen

### UI Tests
- Kritische User Journeys automatisiert testen
- Accessibility Testing integrieren
- Performance-Tests für UI Responsiveness

## Git Workflow

### Branch Strategy
- `main`: Production-ready code
- `develop`: Integration branch
- `feature/*`: Feature-spezifische Branches
- `bugfix/*`: Bug-Fix Branches
- `claude/*`: AI-generierte Branches

### Commit Messages
- Präfix: `feat:`, `fix:`, `docs:`, `refactor:`, `test:`, `chore:`
- Beschreibend und präzise
- Referenziere Issues wo relevant

### Pull Requests
- Code Review vor Merge
- Tests müssen grün sein
- SwiftLint-Checks bestehen
- Dokumentation aktualisiert

## Security Best Practices

### Data Protection
- Keine sensiblen Daten in Logs
- Security-Scoped Bookmarks für Ordnerzugriffe
- Sandboxing beachten
- User Privacy respektieren

### Code Signing
- Developer ID signierte Builds
- Notarization für Distribution
- Entitlements minimal halten

## Deployment

### Build Configuration
- **Debug:** Entwicklung mit Debug-Symbolen
- **Release:** Optimiert, Code-Signing aktiviert
- **Version Numbering:** Semantic Versioning (Major.Minor.Patch)

### Distribution
- **TestFlight:** Beta-Testing über TestFlight
- **App Store:** Finale Distribution
- **Direct Distribution:** Developer ID signiert

## Continuous Integration

### Automated Checks
- Build-Validierung bei jedem Push
- Unit Test Execution
- SwiftLint Code Quality Checks
- UI Test Automation

### Release Process
- Version Bump in Xcode Project
- Changelog Update
- Git Tag erstellen
- Build & Archive für Distribution

---

**Letzte Aktualisierung:** November 2025
**Xcode Version:** 26.x
**macOS Target:** Tahoe (26.x)
**SwiftUI Version:** 6.x
