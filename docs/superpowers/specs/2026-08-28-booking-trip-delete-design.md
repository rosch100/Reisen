# Buchung löschen / Reise löschen mit Buchungs-Option

**Datum:** 2026-08-28  
**Status:** Entwurf für Implementierung (`/feature-dev`)  
**Plattformen:** macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`)

## Ziel

1. **Buchung löschen** ist eine vollständige, HIG-konforme destruktive Aktion: Frage-Titel mit Namen, Folgen-Text, destruktiver Bestätigen-Button, Abbrechen. Gilt für **jede** Buchung (manuell und Anbieter), nicht nur `ProviderID.manual`.
2. **Reise löschen** bietet gemäß HIG eine **Option**, die enthaltenen Buchungen mitzulöschen — oder die Reise allein zu löschen (Buchungen werden offene Buchungen).

## Ist-Zustand

| Aktion | Verhalten |
|--------|-----------|
| Reise löschen | `TripDeletion.perform` entkoppelt Buchungen (`trip = nil`), löscht die Reise. Ein Confirm, ein Button „Löschen“. Message: Buchungen bleiben offen. |
| Buchung löschen | Nur `provider == .manual`. `confirmationDialog` mit Titel „Löschen…“ (kein Frage-Titel, keine Message). macOS/iOS Detail + Timeline/Kontextmenü. |
| Von Reise entfernen | Unverändert (nicht Teil dieser Spec). |
| SwiftData | `SDTrip.bookings` = `.nullify`. `SDTrip.gaps` = `.cascade`. Buchungs-Kinder (Deadlines, Rate, Passagiere, Hints) = `.cascade`. |

`TripDeletion.confirmationMessage` ist ein hardcodierter deutscher String und dupliziert `L10nKey.tripDeleteConfirmMessage`. Beide entfallen nach der Umstellung. UI-Copy nur noch Empty- vs. With-Bookings-Keys. `tripDeleteManualHelp` entfällt zugunsten `bookingDeleteHelp` (Delete gilt nicht nur manuell).

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---------|-----------|
| **Buchung löschen** | Persistentes Entfernen der `SDBooking` inkl. Cascade-Kinder. Nicht dasselbe wie **Von Reise entfernen**. |
| **Reise löschen** | Persistentes Entfernen der `SDTrip` inkl. Gap-Cascade. |
| **Nur Reise löschen** | Reise weg; zugeordnete Buchungen bleiben als **offene Buchungen** (`trip == nil`). |
| **Reise und Buchungen löschen** | Reise und alle aktuell zugeordneten Buchungen weg. |
| **Offene Buchungen** | Buchungen ohne `trip`. |
| **Manuelle Buchung** | `ProviderID.manual` — kommt nicht vom Provider-Sync. |
| **Anbieter-Buchung** | Jede andere `ProviderID` — nächster Sync kann sie per `externalUrl` erneut upserten. |
| **Bestätigungsdialog** | SwiftUI `confirmationDialog` (Action Sheet / AppKit-Äquivalent). |
| **Alarm** | SwiftUI `alert` für eine einzelne destruktive Entscheidung. |

## HIG-Entscheidungen

Apple HIG: destruktive Aktion braucht Confirm oder Undo. **Mehrere Alternativen** → Bestätigungsdialog; **eine** irreversible Entscheidung mit Erklärtext → Alarm. Nur die **am stärksten destruktive** Aktion trägt `role: .destructive`. Menüeinträge, die einen Dialog öffnen, behalten die Ellipse (`…`). Kein „Sind Sie sicher?“.

### Buchung löschen → Alarm

- **Titel:** `Buchung „{presentationTitle}“ löschen?`
- **Message (manuell):** Die Buchung wird unwiderruflich aus Reisen entfernt.
- **Message (Anbieter):** Wie manuell, plus: Nach dem nächsten Provider-Sync kann sie wieder erscheinen, wenn sie beim Anbieter noch existiert.
- **Buttons:** Löschen (`.destructive`), Abbrechen (`.cancel`).
- **Einstiege:** Detail (macOS Inspector, iOS Actions), Timeline-Kontextmenü, Sidebar-Buchungs-Kontextmenü — **ohne** `provider == .manual`-Guard.

### Reise löschen → Bestätigungsdialog

- **Titel:** `Reise „{title}“ löschen?` über `tripDeleteConfirmTitleNamed`. Fallback ohne Namen (leerer Titel): bestehendes `actionDeleteTripConfirm` (`Reise löschen?`) — kein dritter Fragetext.
- **Wenn `resolvedBookings.isEmpty`:** ein Button **Löschen** (`.destructive`) + Abbrechen. Message: Reise und zugeordnete Lücken werden gelöscht.
- **Wenn Buchungen vorhanden:**
  - **Reise und Buchungen löschen** (`.destructive`) — stärkste Aktion
  - **Nur Reise löschen** (ohne destructive-Role)
  - **Abbrechen**
  - Message erklärt beide Optionen und den Sync-Hinweis für Anbieter-Buchungen.
- **Einstiege:** Sidebar-Kontextmenü, iOS Toolbar-Menü, iOS Swipe (`allowsFullSwipe: false` bleibt).

Swipe öffnet denselben Dialog; Full-Swipe-ohne-Confirm bleibt verboten.

## Persistenz (ReisenData)

Keine Parallel-API. UI ruft nicht mehr `modelContext.delete` für Reise/Buchung auf diesen Pfaden.

```
TripDeletion.perform(trip:in:bookings:)
  keepAsOpen        → trip=nil für jede zugeordnete Buchung, dann Trip löschen, save
  deleteContained   → jede zugeordnete Buchung löschen, dann Trip löschen, save

BookingDeletion.perform(booking:in:)
  → Booking löschen, save
```

`TripDeletion.confirmationMessage` entfällt (Copy-SSOT = L10n). `tripDeleteConfirmMessage` und `tripDeleteManualHelp` nach Cutover aus `L10nKey` + Catalog entfernen — sonst zwei Bedeutungen von „Reise löschen“ / „manuell löschen“. Gaps der Reise bleiben `.cascade`. Einzelnes Buchungs-Löschen nullifiziert Gap-Endpunkte wie bisher (kein Gap-Rebuild in dieser Spec). Cascade-Kinder der Buchung (mindestens `SDCancellationDeadline`) werden mit der Buchung entfernt.

Fehler: `throws`. Jede Delete-Call-Site (macOS ContentView/TripDetailView/Open-Booking-Detail, iOS ReisenTab/TripDetailIOS/BookingDetailIOS) zeigt Persistenzfehler in einem Alert. ReisenTabs heutiges leeres `catch` und alle `try?` auf diesen Pfaden entfallen. Abbrechen am Dialog ändert nichts (kein Perform).

## Sync (bewusst kein Tombstone)

Anbieter-Buchungen werden beim nächsten Sync über `externalUrl` erneut angelegt, wenn sie noch im Provider-Konto sind. **Kein** Schema für Tombstones/Ausschlusslisten in dieser Spec (YAGNI). Die Alarm-/Dialog-Texte machen die Folge sichtbar — kein stiller Restore ohne Vorwarnung.

## Schicht-Landung

| Was | Wo |
|-----|-----|
| `TripDeletionBookingPolicy`, `TripDeletion`, `BookingDeletion` | `ReisenData` (SD*-Models, wie bestehendes `TripDeletion`) |
| L10n-Keys + de/en | `ReisenDomain` (`L10nKey`, `Localizable.xcstrings`) |
| Alarm/Bestätigungsdialog-Modifier | `ReisenSharedUI` (`BookingTripActions.swift` erweitern) |
| macOS-Verdrahtung | `Reisen` (`ContentView`, `TripDetailView`, `BookingDetailContent`, `SidebarSelection`) |
| iOS-Verdrahtung | `ReiseniOS` (`ReisenTab`, `TripDetailIOS`, `BookingDetailIOS`) |

Domain bleibt SwiftData-frei. Kein neues Modul.

## UI-Nachlauf

- Nach **Buchung löschen** auf iOS: `dismiss()`, nicht auf „Buchung fehlt“ stehen bleiben.
- Nach **Buchung löschen** auf macOS: Timeline-Selektion auf verbleibende Buchung oder `nil`.
- Nach **Reise löschen** auf iOS: `dismiss()` wie bisher.
- Nach **Reise löschen** auf macOS: Selektion nicht auf gelöschter Trip-ID belassen (bestehende Logik).

Notification `reisenRequestDeleteManualBooking` wird zu `reisenRequestDeleteBooking` umbenannt (ein Name = eine Bedeutung).

`onRequestManualDeleteBooking` / `requestDeleteManualBooking` / `pendingManualDeleteBookingID` analog umbenennen.

## Out of Scope

- Von Reise entfernen (Confirm bleibt)
- Store-Reset, iCloud-Wipe
- Undo/`NSUndoManager`
- EventKit-/Reminder-Rebuild unmittelbar nach Delete (bestehender Launch/Sync-Pfad)
- Gap-Neuberechnung nach einzelnem Buchungs-Löschen
- Tombstone / Sync-Exclusion
- Provider-Portal stornieren

## Akzeptanz

1. Manuelle und Anbieter-Buchung: Einstieg „Löschen…“ → Alarm mit Namen → Abbrechen ändert nichts → Löschen entfernt die Buchung und Kinder.
2. Anbieter-Alarm enthält Sync-Hinweis; manueller Alarm nicht.
3. Reise ohne Buchungen: ein destruktiver Button; Reise weg.
4. Reise mit Buchungen: zwei Aktionen; „Nur Reise löschen“ lässt Buchungen unter Offenen; „Reise und Buchungen löschen“ entfernt sie.
5. Dieselben Dialoge auf macOS und iOS (SharedUI).
6. Tests in `ReisenDataTests` belegen beide Trip-Politiken, Buchungs-Löschen **inkl. Cascade-Kinder**, und dass Abbrechen nicht implementiert werden muss (kein Perform). `ReisenSharedUITests` belegen Copy-Helfer: Sync-Hinweis nur bei `showsSyncRestoreWarning == true`; Trip-Message Empty vs. With-Bookings über `bookingCount`. Alle `L10nKey`s lösen de/en auf.

## Alternativen (verworfen)

| Ansatz | Grund gegen |
|--------|-------------|
| Nur manuelle Buchungen löschbar lassen | „Reise und Buchungen“ wäre sonst eine Sonderfähigkeit ohne Einzelaktion; zwei Bedeutungen von „löschen“. |
| Immer Buchungen mitlöschen, ohne Option | Bricht das bestehende, gültige „offen lassen“. |
| Zwei gestapelte Dialoge (erst Reise, dann Buchungen?) | Mehr Taps; HIG will Alternativen in **einem** Bestätigungsdialog. |
| Tombstones in v1 | Schema + Sync-Index; nicht nötig für HIG-Löschen. |
