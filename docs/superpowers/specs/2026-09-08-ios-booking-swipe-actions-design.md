# iOS Swipe-Aktionen für Buchungen (HIG)

**Datum:** 2026-09-08  
**Status:** Spezifikation für Implementierung (`/feature-dev`)  
**Plattformen:** iOS/iPadOS (`ReiseniOS`); SharedUI-SSOT; macOS unverändert

## Ziel

Buchungszeilen auf iOS sollen **sinnvolle, HIG-konforme Swipe-Gesten** bekommen — insbesondere in der **Reise-Timeline**:

1. **Löschen** (destruktiv, mit bestehendem Confirm-Alarm)
2. **Von Reise entfernen** (mit bestehendem Confirm-Dialog)

Bestehende Swipes (Reise-Liste löschen, offene Buchung löschen / Neue Reise) bleiben und werden an dieselbe **Policy-SSOT** angebunden, wo sie Buchungen betreffen.

## Ist-Zustand

| Oberfläche | Swipe heute | Lücke |
| --- | --- | --- |
| `ReisenTab` Trip-Zeilen | Trailing **Löschen** → Trip-Confirm (`allowsFullSwipe: false`) | OK (Trip, nicht Buchung) |
| `OffenTab` offene Buchung | Trailing **Löschen**; Leading **Neue Reise…** (Compact) | Keine Policy-SSOT; funktioniert |
| `TripDetailIOS` Timeline-Buchung | **kein** Swipe; Context-Menü nur Löschen… (kein Entfernen) | Primärlücke |
| `BookingDetailIOS` | Aktionen in Section (Löschen / Entfernen) | Detail bleibt; Swipe ergänzt die Liste |

Persistenz und Confirm-Copy sind SSOT aus `2026-08-28-booking-trip-delete` / `BookingTripActions` / `BookingTripDeleteModifiers`. Label-Ellipsen: `2026-09-02-menu-action-labels-hig` — **Swipe-Buttons** nutzen kurze Labels **ohne** `…` (`common.delete`, `common.remove`), weil der Button den Confirm öffnet (wie bestehende Offen-/Reisen-Swipes). Menüeinträge behalten `…`.

## Begriffe

| Begriff | Bedeutung |
| --- | --- |
| **Buchung löschen** | `BookingDeletion.perform` — irreversibel (Anbieter: Sync-Hinweis im Alarm) |
| **Von Reise entfernen** | `booking.trip = nil` + save — Buchung wird offen |
| **Swipe-Policy** | Welche Aktionen an trailing/leading in welchem Kontext, inkl. Reihenfolge |
| **Full-Swipe** | `allowsFullSwipe: true` — für destruktive Confirms **verboten** |
| **Trip-assigned** | Buchung mit `trip != nil` in der Timeline |
| **Open booking** | `trip == nil` in Offen-Liste |

## Ansätze (Entscheidung)

| Ansatz | Idee | Urteil |
| --- | --- | --- |
| **A — Dual-Edge (gewählt)** | Trailing = Löschen; Leading = Von Reise entfernen (Trip) bzw. Neue Reise (Offen, Compact) | HIG: destruktiv rechts, sekundär links; analog Mail/Reminders; passt zu bestehendem Offen-Muster |
| B — Nur Trailing-Stack | Beide destruktiven Aktionen trailing | Überladen; Entfernen konkurriert mit Löschen; schlechtere Entdeckbarkeit der schwächeren Aktion |
| C — Nur Detail | Kein Timeline-Swipe | Lehnt Nutzer-Intent ab |

**Verworfen:** Custom `DragGesture`, Full-Swipe-Delete ohne Confirm, neues Persistenz-API.

## HIG-Vertrag

Apple HIG (Lists / destructive): Confirm oder Undo; Full-Swipe ohne Confirm für irreversibles Löschen vermeiden.

| Kontext | Trailing (`allowsFullSwipe: false`) | Leading (`allowsFullSwipe: false`) |
| --- | --- | --- |
| Trip-assigned Buchung | **Löschen** (`common.delete`, `.destructive`) → Booking-Delete-Alarm | **Entfernen** (`common.remove`, Tint nicht `.red` — `.orange`) → Remove-Confirm |
| Open booking | **Löschen** (wie heute) | **Neue Reise…** wenn Compact (`CreateTripFromBookingsLabel` / bestehender Tint `.accentColor`); Split: kein Leading (wie heute) |
| Trip-Zeile (`ReisenTab`) | Unverändert Trip-Delete (nicht Teil der Booking-SSOT) | — |
| Gap-Zeile | Kein Booking-Swipe | — |

Nach Swipe-Tap: **derselbe** Confirm-Pfad wie Menü/Detail (`bookingDeleteConfirmAlert` / Remove-`confirmationDialog`). Abbrechen ändert nichts. Perform erst nach Confirm.

### Context-Menü-Parität (TripDetailIOS)

Zusätzlich zum Swipe: Context-Menü einer Timeline-Buchung enthält **Von Reise entfernen…** (`actionRemoveFromTrip`, destructive) **vor** Löschen… — Parität zu macOS Timeline / Detail.

## Schicht-Landung

| Was | Wo |
| --- | --- |
| `BookingRowSwipeAction`, `BookingRowSwipeContext`, `BookingRowSwipeActions` | `ReisenSharedUI` (pure Policy, testbar) |
| Optional kurze Tint-Hilfe / Identifier | `UITestingIdentifiers` |
| Confirm-Modifier (reuse) | `BookingTripDeleteModifiers` |
| Wiring Trip-Timeline | `Apps/ReiseniOS/.../TripDetailIOS.swift` |
| Wiring Offen (SSOT anbinden) | `Apps/ReiseniOS/.../OffenTab.swift` |
| Unit-Tests | `Tests/ReisenSharedUITests/BookingRowSwipeActionsTests.swift` |
| Logging | `TripDetailIOS`: Remove Start/Erfolg/Fehler analog Delete; Swipe selbst kein Extra-Event wenn Confirm+Perform geloggt |

Keine Domain-/Schema-Änderung. Kein macOS-Diff nötig.

## Policy-API (Kontrakt)

```swift
public enum BookingRowSwipeAction: String, Equatable, Sendable, CaseIterable {
    case delete
    case removeFromTrip
    case createTripFromBooking
}

public enum BookingRowSwipeEdge: Equatable, Sendable {
    case trailing
    case leading
}

public enum BookingRowSwipeContext: Equatable, Sendable {
    /// `offersCreateTripOnLeading`: Compact-Phone-Liste; Split = false
    case openBooking(offersCreateTripOnLeading: Bool)
    case tripAssignedBooking
}

public enum BookingRowSwipeActions {
    /// Geordnet: Index 0 = äußerste / primäre Swipe-Taste der Kante.
    public static func actions(
        for context: BookingRowSwipeContext,
        edge: BookingRowSwipeEdge
    ) -> [BookingRowSwipeAction]
}
```

Semantik:

- `tripAssignedBooking` + trailing → `[.delete]`
- `tripAssignedBooking` + leading → `[.removeFromTrip]`
- `openBooking(true)` + trailing → `[.delete]`; leading → `[.createTripFromBooking]`
- `openBooking(false)` + trailing → `[.delete]`; leading → `[]`

View-Layer mappt Aktionen auf Buttons + Labels + Tints; ruft bestehende Request-/Confirm-Handler auf.

## Logging

| Pfad | Events |
| --- | --- |
| Booking delete (bereits) | Persist-Failure in TripDetailIOS |
| Remove from trip (neu in Timeline) | `booking_remove_from_trip` started/succeeded/failed (`TripDetailIOS`, visibility publicDiagnostic bei fail; localDebug bei success optional — mind. fail wie Detail) |

Keine PII/Titel in `reason`.

## Identifier

| ID | Verwendung |
| --- | --- |
| `reisen.swipe.booking.delete` | Trailing Delete-Button (Booking-Rows) |
| `reisen.swipe.booking.remove-from-trip` | Leading Remove-Button |
| Bestehende Row-IDs | `bookingRow(id)` unverändert (eine ID pro Row) |

Keine Doppel-ID mit Sidebar/macOS. iOS-XCUI-Target fehlt → Identifier pflegen, Automation = `open_gaps`.

## Handler-Trace (Ist → Soll)

Swipe/Menü setzen nur Pending + Present. Persistenz nur in Confirm-Handlern.

| Journey | Ist-Handler heute | Soll (v1) | Side-Effect vor Confirm? |
| --- | --- | --- | --- |
| Trip Timeline Swipe trailing → Löschen | — (kein Swipe) | Button → `pendingDeleteBooking` + `showBookingDeleteConfirm` | nein |
| Trip Timeline Swipe leading → Entfernen | — | Button → `pendingRemoveBooking` + `showRemoveFromTripConfirmation` | nein |
| Trip Context → Löschen… | `pendingDeleteBooking` + alert → `BookingDeletion.perform` | unverändert | nein |
| Trip Context → Entfernen… | fehlt | wie Swipe leading → derselbe Confirm | nein |
| Trip Confirm Delete | `deletePendingBooking` → `BookingDeletion.perform` | unverändert | Perform nur hier |
| Trip Confirm Remove | — | `removePending…` → `trip = nil` + `save` (wie `BookingDetailIOS.removePendingBookingFromTrip`) | Perform nur hier |
| Trip Confirm Cancel | `pendingDeleteBooking = nil` | analog Remove clear | keine Persistenz |
| Offen Swipe trailing Delete | `requestDeleteBooking` → Confirm → Delete | dieselben Handler; Button aus Policy + Identifier | nein |
| Offen Swipe leading CreateTrip | `createTripFromBooking` → Sheet-Seed (**Act**, kein Delete) | unverändert; Policy steuert Sichtbarkeit | Sheet-Seed ist gewollt (nicht destruktiv) |
| Gap-Zeile | kein Booking-Swipe | unverändert | — |

`TripTimelineSection` reicht `bookingRow` durch — Swipe hängt am Closure in `TripDetailIOS`, nicht in SharedUI-Section.

## Schnittstellen-Inventar

Profil: `live_app`. Nicht `port-only`.

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| swipe-policy-contract | contract | `BookingRowSwipeActions.actions(for:edge:)` Matrix Spec | `BookingRowSwipeActionsTests` (alle 6 Kontext×Edge) |
| trip-booking-swipe-entry | entry | `TripDetailIOS` trailing/leading `swipeActions(allowsFullSwipe: false)` → Pending+Confirm → Delete/Remove | Unit + Code-Review Handler-Trace; iOS-XCUI = **open_gaps** |
| trip-booking-context-remove | entry | Context-Menü `actionRemoveFromTrip` → derselbe Remove-Confirm wie Swipe | Code-Diff + Handler-Trace |
| open-booking-swipe-neighbor | neighbor | `OffenTab` Trailing/Leading aus derselben Policy; bestehende `requestDeleteBooking` / CreateTrip | Diff Call-Sites + Unit Policy |
| confirm-delete-neighbor | neighbor | `bookingDeleteConfirmAlert` / `BookingDeletion.perform` | Bestehende Modifier + TripDetail Wiring |
| confirm-remove-neighbor | neighbor | Remove-`confirmationDialog` + `trip = nil` + save | `BookingTripConfirmDialogs` Pattern / TripDetail |
| live-app-identifiers | entry | `reisen.swipe.booking.delete`, `reisen.swipe.booking.remove-from-trip` je einmal an Swipe-Buttons; `bookingRow(id)` unverändert | `UITestingIdentifiers` + Wiring Task 2/3 |
| live-app-handler-trace | entry | Tabelle oben; Full-Swipe aus; Perform erst nach Confirm | Spec + Diff-Review |
| live-app-isolation | capability | Keine neuen `@AppStorage` / `UserDefaults.standard` / `supportDirectoryURL` / Suite-Hooks im Diff | Isolation-Grep unten + Diff |
| live-app-assert-vs-act | contract | Keine iOS-XCUI-Mutation in v1; Identifier Reach-only | Spec `open_gaps` |
| live-app-ui-compile | contract | Kein neues SwiftUI im MacUI-Runner | Diff ohne MacUI-Produktimport |
| live-app-process-hooks | capability | Kein neuer `use(suite)` | Diff-Grep |

## Isolation-Grep (Ist-Baseline, Feature-Fläche)

Command (vor/nach Diff wiederholen):

```bash
rg -n '@AppStorage|UserDefaults\.standard|supportDirectoryURL|fromUserDefaults|use\(suite\)' \
  Apps/ReiseniOS/Shared/TripDetailIOS.swift \
  Apps/ReiseniOS/Shared/OffenTab.swift \
  Apps/ReiseniOS/Shared/BookingDetailIOS.swift \
  Sources/ReisenSharedUI/BookingTripDeleteModifiers.swift \
  Sources/ReisenSharedUI/BookingRowSwipeActions.swift \
  Sources/ReisenSharedUI/UITestingIdentifiers.swift \
  Sources/ReisenSharedUI/TripGapsSection.swift
```

| Datei | Treffer (Baseline master) | Journey-Wirkung |
| --- | --- | --- |
| `TripDetailIOS.swift` | keine | — |
| `OffenTab.swift` | keine in Swipe-/Delete-Pfad (Baseline: 0 Matches auf den Mustern) | CreateTrip/Delete nutzen ModelContext, nicht UserDefaults |
| `BookingDetailIOS.swift` | keine | Remove/Delete nur ModelContext |
| `BookingTripDeleteModifiers.swift` | keine | — |
| `UITestingIdentifiers.swift` | keine | — |
| `TripGapsSection.swift` | keine | — |
| `BookingRowSwipeActions.swift` | n/a (neu, pure) | darf keine der Muster enthalten |

**Diff-Invariante:** keine neuen Treffer der Muster in diesem Diff. Bestehende App-weite `@AppStorage` außerhalb der Fläche sind Launch-Nachbarn und werden von dieser Journey nicht geschrieben.

## Tests / Evidence

| Evidence | Inhalt |
| --- | --- |
| `BookingRowSwipeActionsTests` | **6** Fälle: trip trailing/leading; open Compact/Split × trailing (`[.delete]`) und leading |
| Wiring | `allowsFullSwipe: false`; Identifier an Delete- und Remove-Swipe-Buttons (Trip); Delete-ID an Offen-Trailing |
| `ci-test.sh` / `ios-test.sh` | SharedUI + iOS Unit/Smoke grün |
| Isolation-Grep | Command oben; Diff-Invariante |
| iOS-XCUI | `open_gaps` an `trip-booking-swipe-entry` |

## Out of Scope

- macOS Trackpad-Swipe / Table-Swipe
- Batch-Swipe Multi-Select auf iOS
- Gap-Swipe
- Undo-Manager statt Confirm
- Full-Swipe
- Neue Persistenz / Tombstones
- iOS-XCUI-Target aufbauen

## Akzeptanz

1. In einer Reise: Swipe rechts → Löschen → Alarm → Confirm entfernt Buchung; Abbrechen belässt sie.
2. In einer Reise: Swipe links → Entfernen → Confirm → Buchung erscheint unter Offen; Abbrechen belässt Zuordnung.
3. Offen: Verhalten unverändert (Delete / Create-Trip Compact), aber Policy aus SSOT.
4. Context-Menü Timeline enthält Entfernen… und Löschen….
5. Nirgends `allowsFullSwipe: true` auf Booking-/Trip-Delete-Swipes dieses Diffs.
6. Unit-Tests decken die 6er-Policy-Matrix ab; Logging auf Remove-Fehlerpfad.
7. Swipe-Buttons tragen die Spec-Identifier (Trip Delete+Remove; Offen Delete).
