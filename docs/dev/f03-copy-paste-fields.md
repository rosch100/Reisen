# F03 — Copy/Paste für Info- und Editor-Felder

Stand: 2026-08-28  
Status: umgesetzt (Branch `feat/f03-copy-paste-fields`)

## Ziel

Jeden fachlichen **Info-Wert** ohne Markier-Akrobatik kopieren; in **Editoren** systemisches Cut/Copy/Paste vollständig nutzbar machen — HIG-konform, eine Copy-SSOT, ohne Chrome-Buttons an jeder Zeile.

## Copy-Stufen

| Kind | Felder | Verhalten |
|------|--------|-----------|
| `standard` | Orte, Zeiten, Preis, Status, Policy, Hinweise, Notizen, LastSynced, Gap-/Trip-Facts | Selektion + Kontextmenü „Kopieren“ (nur Wert) |
| `identifier` | `confirmationCode` (Buchung + Zimmerposition) | Tap/Klick kopiert; monospaced; Haken neben dem Wert; VoiceOver-Action „Kopieren“ |

**URL / Links:** Tap öffnet. Kontextmenü „Link kopieren“ schreibt `absoluteString`. Kein Identifier-Kind.

**Payload:** immer der volle Modellwert (auch bei Truncation); nie `"Label: Wert"`; leerer Wert → Pasteboard unverändert.

## Architektur

- `StringPasteboard` / `StringPasteboardClient` + Environment (Spy in Tests)
- `FieldCopyKind` am `BookingRateField` (Katalog in `BookingScheduleFields` / `BookingRateFields`)
- `CopyableFieldValue` / `CopyableLabeledValue` (iOS `.list` = `LabeledContent`, macOS `.inspector` = Caption + `CopyableTextView`)
- `BookingCopyConfirmationMenuItems` in allen Booking-Kontextmenüs
- `CopyableTextView` / `CopyableNSTextView` in `ReisenSharedUI` (macOS); Sync-Fehler weiter über `CopyableLabel`

## Editoren

- Kein `contextMenu` / Trailing-Copy auf `TextField` (System-Edit-Menü bleibt)
- Provider-`LabeledContent` und abgeleitete Read-only-Texte: `copyableValue`
- `textContentType`: Namen (Passagier), URL-Feld (+ iOS `.keyboardType(.URL)`)

## Out of Scope

- Clipboard-Monitoring / Paste-Import → F06
- Share-Snapshot / ICS → F04
- Rich-Text in der Zwischenablage
- Aufblasen von `bookingFullCopyText` auf alle Felder

## Manuelle HIG-Prüfung

1. iOS Buchungsdetail: jede Schedule-Zeile eigenes Kontextmenü; Copy = nur Wert
2. Buchungsnr. antippen: Haken neben dem Code, Zwischenablage = Code
3. Preis: Teilstring markieren und kopieren
4. Browser-Link: Tap öffnet; Long-Press/Rechtsklick kopiert URL
5. macOS Inspector: Kennung per Kontextmenü oder Doppelklick kopieren; Einfachklick + Ablage→Kopieren ohne Markierung; Secondary/Grün-Farben wie auf iOS
6. Editor: natives Cut/Copy/Paste; kein Extra-Copy-Button; Provider-Zeile kopierbar
7. Leere Buchungsnr.: Copy ändert Pasteboard nicht
8. Offen-Tab / Timeline: „Buchungsnr. kopieren“ nur mit Code
9. VoiceOver: Action „Kopieren“ an Kennungszeile; Ansage „Kopiert“ (iOS + macOS)
10. Truncated Notes/Policy: Zwischenablage enthält vollen Text
11. Sync-Fehler-`CopyableLabel` unverändert
12. iOS Room/Storno/Hints: je Item/Deadline/Hinweis eigene List-Zeile
13. Zwischenablage immer Plain-Text (auch bei Markierung in NSTextView)
14. Gap-Info (iOS Kontextmenü / macOS Details): Titel, Zeitraum, Typ, Preis — jeweils nur der Wert, kein `"Label: Wert"`
