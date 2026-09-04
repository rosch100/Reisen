# Changelog

Alle nennenswerten Änderungen an Reisen. Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [0.2.2] — 2026-09-04

### Added
- Paste-Import von Buchungsbestätigungen (PDF, Bild, Text) mit Review vor dem Speichern
- Kostensumme der Reise inkl. Summen je Währung und optionaler FX-Umrechnung (Frankfurter/ECB, Opt-in)
- Automatische Lücken-Vorschläge (Auto-Gap) bei Reiseänderungen
- Globale Tagesüberschneidungen von Buchungen (macOS und iOS)
- Mehrfachauswahl mit Sammelaktionen (Zuordnen/Löschen) in Sidebar und Timeline
- Hierarchische Reiseübersicht (HIG-Typografie)
- Storno-Portal-Links für Sync-Anbieter (wo verfügbar)
- Debug-Logging für macOS: `bash ./Scripts/run-app.sh --logging`

### Changed
- Sync-Preise in bevorzugter App-/Locale-Währung
- Menü- und Aktionslabels an Apple HIG angeglichen
- Buchungsdetail zeigt nur noch nutzerrelevante Felder
- Offen/Abgelaufen-Sidebar: expandierbare Outline, HIG-Kontextmenüs
- CI: parallele Suite-Jobs mit Aggregator-Gate

### Fixed
- Check24-Hoteladresse und Stay-Felder aus Portal-Details
- Traveloka: stornierte/refundierte Buchungen zuverlässiger erkannt
- Zwischentransporte nur mit Stadt-/Ortsnamen; Log-Lücken ohne erfundene Bahn
- Timeline-/Sidebar-Mehrfachauswahl und Batch-Menüs bei Gaps

## [0.2.1] — 2026-07-24

Siehe GitHub Release [v0.2.1](https://github.com/rosch100/Reisen/releases/tag/v0.2.1).

[0.2.2]: https://github.com/rosch100/Reisen/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/rosch100/Reisen/releases/tag/v0.2.1
