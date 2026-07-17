# Copyable Content UI — Design

Datum: 2026-07-17  
Status: freigegeben (Brainstorming)

## Ziel

Alle inhaltlichen Anzeigen in der Reisen-macOS-App sollen per Selektion und CMD+C kopierbar sein — insbesondere Fehlermeldungen und Status-/Sync-Meldungen. Reine UI-Steuerungstexte (Buttons, Menüs, Chrome-Labels) bleiben ausgenommen.

## Anforderungen

### Scope (Variante B)

| In Scope | Außer Scope |
|----------|-------------|
| Fehler-, Status- und Keychain-Meldungen | Button-Titel |
| URLs (z. B. letzte Sync-URL) | Menüeinträge |
| Buchungs-/Reisedaten, Notizen, Detailwerte | Reine Steuerungs-Labels in Sidebar/Chrome |
| Fehlermeldungen in Sheets und Store-Failure-View | |

### Copy-Verhalten (Variante C + Fokus A)

1. Klick in einen Inhalts-Textblock macht ihn First Responder.
2. Ist Text markiert → CMD+C kopiert die Markierung.
3. Ist nichts markiert → CMD+C kopiert den kompletten `copyText` des fokussierten Blocks.
4. Pasteboard: Plain-Text (`String`) nur.
5. Icons (z. B. SF Symbols neben Fehlermeldungen) gehören nicht in den kopierten Text.

## Architektur

### Gewählter Ansatz

Wiederverwendbare AppKit-Brücke (Generalisierung des bestehenden `SelectableBookingTextView`-Musters), gezielt für Inhaltsanzeigen — nicht pauschal jedes `Text` durch `NSTextView` ersetzen, und nicht nur SwiftUI `.textSelection(.enabled)` (reicht für „ganzen Block ohne Markierung“ nicht zuverlässig).

### Komponenten

1. **`CopyableTextView`** (NSViewRepresentable um nicht-editierbares `NSTextView`)
   - Eingaben: Anzeigetext (plain und/oder attributed) und `copyText`
   - `isEditable = false`, `isSelectable = true`
   - Override von `copy(_:)` / `writeSelection`: Selektion falls vorhanden, sonst `copyText`
   - Leerer `copyText`: Pasteboard nicht überschreiben / kein sinnloses Copy
   - Klick akzeptiert First Responder (macOS-Standard)

2. **SwiftUI-Helfer** (z. B. `CopyableLabel` oder vergleichbarer Wrapper)
   - Icon + kopierbarer Text für Sync-Fehler-/Statuszeilen
   - Visuelle Parität zu bisherigen `Label(...)`-Zeilen

3. **Refactor `SelectableBookingTextView`**
   - Nutzt dieselbe Copy-/Responder-Basis (eine Implementierung der Copy-Semantik)
   - Fachliche Attributed-/Tab-Stop-Logik der Buchungsdetails bleibt dort

### Einsatzorte

- `SyncView`: composition-/keychain-/store-Fehler, Statusmeldung, letzte URL
- `StoreFailureView`: Fehlermeldung (bereits teilweise `.textSelection`; auf Copyable-Verhalten angleichen)
- Sheets mit `errorMessage` (`AssignBookingsSheet`, `TripEditorSheet`, …)
- Listen-/Detailwerte und Notizen, soweit noch nicht über die Buchungs-Copy-Logik abgedeckt
- Bestehende Buchungsdetail-Darstellung: Verhalten erhalten, Basis teilen

## Randfälle

- Mehrzeilige Fehlermeldungen: Umbruch, volle Höhe, gesamter Text ohne Markierung kopierbar
- Mehrere Blöcke: nur der fokussierte (angeklickte) reagiert auf CMD+C
- Icon neben Text: nur Textinhalt in der Zwischenablage

## Prüfung (manuell, macOS)

1. Sync-Fehler anklicken → CMD+C → voller Fehlertext
2. Teil markieren → CMD+C → nur Markierung
3. Statuszeile, URL, Sheet-Fehler analog
4. Buchungsdetail: bisheriges Copy-Verhalten unverändert korrekt
5. Buttons/Sidebar: nicht als Inhaltsblock kopierbar

## Explizit nicht in diesem Design

- Hover-basiertes Copy ohne Klick
- Automatischer Fokus auf den „primären“ Meldungsbereich
- Rich-Text / HTML in der Zwischenablage
- Copy-Buttons neben jeder Zeile (optional später, nicht nötig für CMD+C)
`)