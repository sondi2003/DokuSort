# DokuSort

**Version:** 1.0.3
**Plattform:** macOS
**Autor:** Richard Sonderegger

## Übersicht

DokuSort ist eine intelligente macOS-Anwendung zur automatischen Verwaltung und Archivierung von PDF-Dokumenten. Die App analysiert PDF-Dateien mit künstlicher Intelligenz, extrahiert wichtige Metadaten und organisiert Dokumente automatisch in einer strukturierten Ordnerhierarchie.

## Hauptfunktionen

### Automatische Dokumentenanalyse
- Kontinuierliche Überwachung eines Quellordners auf neue PDF-Dateien
- KI-gestützte Extraktion von Metadaten aus Dokumenten
- Automatische Texterkennung (OCR) mittels macOS Vision Framework
- Intelligente Analyse durch Ollama-Integration für präzise Ergebnisse

### Intelligente Metadaten-Extraktion
DokuSort extrahiert automatisch folgende Informationen:
- **Dokumentdatum**: Das Hauptdatum des Dokuments (nicht Ablauf- oder Lieferdaten)
- **Korrespondent**: Name der ausstellenden Organisation oder Person
- **Dokumenttyp**: Kategorisierung (Rechnung, Offerte, Vertrag, Police, etc.)

### Automatische Organisation
- Strukturierte Ablage nach dem Schema: `Archiv/[Korrespondent]/[Jahr]/[Datum-Typ].pdf`
- Intelligente Normalisierung und Deduplizierung von Korrespondentennamen
- Alias-Mapping für unterschiedliche Schreibweisen von Firmennamen
- Automatische Erstellung der Ordnerstruktur

### Flexibles Datei-Management
- Wahlweise Verschieben oder Kopieren von Dokumenten
- Drei Konfliktlösungsstrategien bei Duplikaten:
  - Benutzer fragen (Standard)
  - Automatische Suffix-Vergabe
  - Überschreiben bestehender Dateien
- Optionale Löschung der Quelldateien nach erfolgreicher Archivierung

### Benutzerfreundliche Oberfläche
- **Dashboard** mit drei Bereichen:
  - Dokumentenliste mit Such- und Filterfunktion
  - PDF-Vorschau mit kontinuierlichem Scrollen
  - Metadaten-Editor zur manuellen Bearbeitung
- Echtzeit-Fortschrittsanzeige während der Analyse
- Statusfilter für Dokumente (Alle, Ausstehend, Analysiert)

### Metadaten-Verwaltung
- Manuelle Bearbeitung und Korrektur extrahierter Daten
- Autocomplete-Vorschläge für Korrespondenten und Dokumenttypen
- Persistente Kataloge bekannter Korrespondenten und Dokumenttypen
- Validierung vor der Archivierung

## Ollama-Integration

DokuSort nutzt **Ollama** für die KI-gestützte Dokumentenanalyse. Ollama ermöglicht den Einsatz lokaler Large Language Models (LLMs) direkt auf Ihrem Mac.

### Vorteile der Ollama-Integration
- Vollständig lokale Verarbeitung ohne Cloud-Anbindung
- Datenschutzfreundlich: Dokumente verlassen nie Ihren Computer
- Mehrsprachige Unterstützung (Deutsch, Englisch)
- Hohe Analysegenauigkeit durch Few-Shot Learning
- Strukturierte JSON-Antworten für zuverlässige Extraktion

### Standardkonfiguration
- **Standard-Modell:** llama3.1
- **Verbindung:** HTTP (Standard: `http://127.0.0.1:11434`)
- Modell und URL können in den Einstellungen angepasst werden

### Analyseprozess
1. Textextraktion aus PDF mittels OCR
2. Parallele Analyse durch Ollama AI und heuristische Methoden
3. Bewertung der Ergebnisse mit Konfidenzwerten
4. Auswahl des besten Analyseergebnisses

## Workflow

1. **Überwachung**: DokuSort überwacht kontinuierlich den konfigurierten Quellordner
2. **Erkennung**: Neue PDF-Dateien werden automatisch erkannt
3. **Analyse**: Dokumente werden im Hintergrund analysiert und Metadaten extrahiert
4. **Überprüfung**: Benutzer kann die vorgeschlagenen Metadaten im Editor überprüfen und anpassen
5. **Archivierung**: Nach Bestätigung wird das Dokument in die strukturierte Ordnerhierarchie abgelegt
6. **Bereinigung**: Optional werden Quelldateien nach erfolgreicher Archivierung entfernt

## Einrichtung

### Voraussetzungen
- macOS (aktuelle Version empfohlen)
- Ollama installiert und konfiguriert
- Ausreichend Speicherplatz für das Dokumentarchiv

### Erste Schritte
1. DokuSort starten
2. In den Einstellungen Quellordner und Archiv-Basisordner festlegen
3. Ollama-Verbindung und Modell konfigurieren
4. Ablage-Verhalten wählen (Verschieben/Kopieren)
5. PDF-Dateien in den Quellordner legen

## Einstellungen

### Ordnerkonfiguration
- **Quellordner**: Ordner, der auf neue PDF-Dateien überwacht wird
- **Archiv-Basisordner**: Zielordner für die strukturierte Ablage

### Ablage-Verhalten
- **Dateioperation**: Verschieben oder Kopieren
- **Quelldateien löschen**: Optional nach erfolgreicher Kopie
- **Konfliktbehandlung**: Strategie bei bereits existierenden Dateien

### Ollama-Konfiguration
- **Basis-URL**: Adresse des Ollama-Servers
- **Modell**: Verwendetes LLM-Modell

## Unterstützte Dokumenttypen

DokuSort erkennt und kategorisiert folgende Dokumenttypen:
- Rechnung
- Mahnung
- Gutschrift
- Offerte
- Police (Versicherung)
- Vertrag
- Lieferschein
- Dokument (Allgemein)

## Dateiformat

- **Unterstützt**: PDF (.pdf)
- **Verarbeitung**: Erste 1-2 Seiten für OCR (Performance-Optimierung)
- **Validierung**: Automatische Überprüfung vor der Verarbeitung

## Katalog-Management

DokuSort pflegt automatisch Listen bekannter Korrespondenten und Dokumenttypen:
- Intelligente Namens-Normalisierung
- Alias-Verwaltung für verschiedene Schreibweisen
- Fuzzy-Matching zur Gruppierung ähnlicher Namen
- Autocomplete-Vorschläge beim manuellen Editieren

## Technische Merkmale

- Native macOS-App mit SwiftUI
- Asynchrone Hintergrundanalyse mit Warteschlangen-System
- Persistente Caching-Mechanismen für Analyseergebnisse
- Datei-System-Überwachung mittels FSEvents
- Security Bookmarks für sichere Ordnerzugriffe
- JSON-basierte Persistierung von Daten und Einstellungen

## Datenschutz

- Alle Analysen erfolgen lokal auf Ihrem Mac
- Keine Übertragung von Dokumenten an externe Server
- Keine Cloud-Anbindung erforderlich
- Vollständige Kontrolle über Ihre Daten

## Support und Feedback

Bei Fragen, Problemen oder Verbesserungsvorschlägen öffnen Sie bitte ein Issue auf GitHub.

## Lizenz

Siehe LICENSE-Datei für Details.

---

**DokuSort** – Intelligente Dokumentenverwaltung für macOS
