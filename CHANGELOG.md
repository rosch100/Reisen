# Changelog

Nennenswerte Änderungen an Reisen. Format angelehnt an [Keep a Changelog](https://keepachangelog.com/de/1.1.0/).

## [0.2.2] — 2026-09-04

### Added
- Paste-Import: Buchungsbestätigung als PDF, Bild oder Text einfügen, prüfen, speichern
- Kostensumme der Reise (je Währung); optionale Umrechnung über Frankfurter/ECB (Opt-in)
- Lücken in der Reise automatisch vorschlagen, wenn sich Buchungen ändern
- Doppelbuchungen am selben Tag (macOS und iOS)
- Mehrere Buchungen oder Reisen markieren und gemeinsam zuordnen oder löschen
- Klarere Reiseübersicht; Storno-Seite des Anbieters öffnen, wenn ein Link da ist
- macOS-Debug: `bash ./Scripts/run-app.sh --logging`

### Changed
- Sync speichert Preise in der bevorzugten App-/Locale-Währung
- Menütexte an Apple HIG angeglichen
- Buchungsdetail ohne überflüssige Technikfelder
- Offen/Abgelaufen in der Sidebar expandierbar, mit passenden Kontextmenüs
- CI: Suites parallel, ein Aggregator-Check als Merge-Gate

### Fixed
- Check24: Hoteladresse und Stay-Felder aus den Portal-Details
- Traveloka: stornierte und refundierte Buchungen zuverlässiger erkannt
- Zwischentransporte nur mit Stadt-/Ortsnamen; keine erfundenen Bahn-Lücken
- Mehrfachauswahl und Batch-Menüs in Timeline/Sidebar bei Lücken dazwischen

## [0.2.1] — 2026-07-24

Siehe GitHub Release [v0.2.1](https://github.com/rosch100/Reisen/releases/tag/v0.2.1).

[0.2.2]: https://github.com/rosch100/Reisen/compare/v0.2.1...v0.2.2
[0.2.1]: https://github.com/rosch100/Reisen/releases/tag/v0.2.1
