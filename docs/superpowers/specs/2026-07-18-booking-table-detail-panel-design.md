# Buchungs-Table mit Detailpanel (macOS 27)

## Ziel

In der Reisedetailansicht (`TripDetailView`) wird die bisherige Timeline-/List-Darstellung der Buchungen durch eine native, kostenlose SwiftUI-`Table` ersetzt.
Die Detailansicht („alle Buchungsdetails“) wird als **ein-/ausblendbares Panel** direkt unterhalb der Tabelle angezeigt (über der Fensterunterkante).

## UI-Verhalten

### Tabelle (eine Spalte)

- Zeilen repräsentieren sowohl **Buchungen** als auch **Lücken/Gaps** (`TimelineItem`).
- Die Zeile zeigt eine kompakte Zusammenfassung (Titel/Zeitraum/Typ/Preis und Überlappungshinweis bei Buchungen).
- Klicken/Selektion aktualisiert das Detailpanel.

### Detailpanel (Segment oberhalb Statusbereich)

- Kann per Toolbar-Button ein-/ausgeblendet werden (`@SceneStorage`).
- Zeigt bei Selektion:
  - Buchung: volle Detailausgabe inkl. Storno-/Fix-/Deadline-Informationen und „Von Reise entfernen“.
  - Gap: Gap-Details inkl. „Bearbeiten“ sowie Deep-Links/Probleme, wenn verfügbar.

## Komponenten / Verantwortlichkeiten

- `TripDetailView`
  - Baut die Datenbasis: `sortedBookings`, berechnete `gaps` und daraus `timelineItems(...)`.
  - Hält Panel- und Table-Selektion: `detailPanelVisible`, `tableSelection`.
  - Liefert Auswahl- und Edit-Callbacks.

- `TimelineRowLabel`
  - Renderet genau eine kompakte Tabellenzeile (Buchung oder Gap) im `summary`-Modus.

- `BookingDetailPanel`
  - Renderet die selektierten Details im `details`-Modus.

- `BookingRow` / `GapRow`
  - Unterstützen `TimelineRowDisplayMode` (`summary` vs. `details`), um doppelte UI-Logik zu vermeiden.

## SSOT für Gap-Presentation

Für die Darstellung von Gaps wird eine zentrale Hilfsstruktur genutzt:

- `GapPresentation` (Key, Titel, effektiver Gap-Typ, Preiswerte/Preistext)
- `gapPresentation(for:)` erzeugt dieses Objekt aus `gapOverrides` + `savedGapsByKey`
- Die `GapPresentation` wird sowohl von Table-Zeilen als auch dem Detailpanel verwendet.

## Smoke-Verification (lokal)

- `swift build` auf dem Projekt durchgeführt und erfolgreich abgeschlossen.
- Compilerfehler nach Umbau (Table/Panel/Selektion) behoben, Build bleibt grün.

