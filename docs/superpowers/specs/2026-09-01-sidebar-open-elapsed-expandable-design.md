# Sidebar: Offene Buchungen & Abgelaufen als Outline-Listen

**Datum:** 2026-09-01  
**Status:** Spec (feature-dev P1)  
**Scope:** macOS-Sidebar in `ContentView` (linke Spalte). iOS `OffenTab` unverändert.

## Intent

„Offene Buchungen“ und „Abgelaufen“ sollen **wie „Reisen“** in der linken Spalte als **ausklappbare Listen** erscheinen: sichtbare Einzelzeilen in der Sidebar-Outline, nicht nur eine Aggregat-/Mailbox-Zeile mit Zähler.

## Ist-Zustand

| Section | Heute | Reisen (Soll-Muster) |
| --- | --- | --- |
| Offene Buchungen | Eine Button-Zeile (Titel + Anzahl) → `selection = .openBookings`; echte Liste nur in der **Content**-Spalte | Section mit vielen Eltern-Zeilen; Expand zeigt Kinder |
| Reisen | Trip-Zeilen + Chevron → zugeordnete Buchungen in der Sidebar | — |
| Abgelaufen | Aggregat-Zeile für elapsed-open + **flache** Trip-Zeilen **ohne** Expand | wie Reisen inkl. Expand |

Nachbar (bewusst beibehalten): Mail-3-Spalten-Layout — Content-Spalte bleibt Buchungsliste, Detail unverändert. Sidebar wird Outline-Navigation parallel zu Reisen, ersetzt die Content-Liste nicht.

## Begriffe (Spec-Terms)

| Begriff | Bedeutung |
| --- | --- |
| **Sidebar-Outline** | Hierarchie in der linken `List` (Section → Zeilen → optionale Kinder) |
| **Aggregat-Zeile** | Eine Zeile „Offene Buchungen (N)“ ohne Einzelbuchungen — **entfernen** zugunsten der Liste |
| **Offene-Buchungs-Zeile** | Eine Sidebar-Zeile pro `OpenBookingMatching.currentUnassigned` |
| **Abgelaufen-Offen-Zeile** | Eine Sidebar-Zeile pro `OpenBookingMatching.elapsedUnassigned` |
| **Trip-Outline** | Trip-Zeile mit optionalem Chevron und Buchungs-Kindern (bereits bei aktuellen Reisen) |
| **Expand-State** | `expandedTripIDs` — gilt für aktuelle **und** abgelaufene Trip-Outlines |

## Anforderungen

### Offene Buchungen

1. Section-Header bleibt `L10n.tripOpenBookings`.
2. Leer: unverändert Hinweis `tripNoOpenBookings`.
3. Nicht leer: **ForEach** über `openBookings` — je Zeile Titel + Kurzdatum (gleicher Informationsgrad wie Trip-Buchungskinder unter Reisen).
4. Klick auf Zeile: `selection = .openBookings` und `selectedOpenBookingIDs = [booking.id]` (Einzel-Fokus; Multi-Select bleibt in der Content-Liste).
5. Kontextmenü „Reise aus allen offenen“: am Section-Header oder als Section-weite Aktion erhalten (nicht still entfernen).
6. Kein Chevron an offenen Buchungen (keine Kinder) — „ausklappbar“ bezieht sich auf die **Listen-Outline** analog zu Reisen-Eltern; Buchungen sind Blätter.

### Abgelaufen

1. Section `bookingElapsed` nur wenn elapsed Trips oder elapsed-open existieren (wie heute).
2. **Abgelaufen-Offen-Zeilen:** wie Offene-Buchungs-Zeilen, aber `selection = .elapsedOpenBookings` + Selection-Set.
3. **Elapsed Trips:** dieselbe **Trip-Outline** wie unter Reisen (Chevron, Expand, Buchungskinder). Context: Edit/Delete wie Ist-Flachzeile; **`allowsAddBooking: false`** (Ist unter Abgelaufen hat kein „Buchung hinzufügen“).
4. **SSOT `sidebarOutlineBookings(isElapsed:)`** auf `SDTrip` (ReisenData):  
   - `isElapsed == false` → bestehende `timelineBookings()`-Semantik (Upcoming/manual, nicht cancelled).  
   - `isElapsed == true` → alle zugeordneten **nicht stornierten** `resolvedBookings`, sortiert nach `startAt`.  
   Begründung: `timelineBookings()` filtert über `appearsInList` und liefert für typische abgelaufene Provider-Buchungen **leer** — Expand wäre nutzlos. Kein stiller Fallback auf `[]` „damit UI nicht crasht“; leere Kinder nur wenn wirklich keine nicht-cancelled Buchungen existieren (dann kein Chevron).
5. Aggregat-Zeile „Offene Buchungen (N)“ unter Abgelaufen **entfernen**.

### Shared / SSOT

1. Trip-Outline-UI für `currentTrips` und `elapsedTrips` **nicht** copy-pasten: `SidebarTripOutline` im App-Target; ein Expand-State (`expandedTripIDs`); Parameter `allowsAddBooking`.
2. Offene Buchungen: weiter `OpenBookingMatching` — keine zweite Matching-Logik.
3. **List-Tag-Strategie (fest):** Offene-/Abgelaufen-Offen-Zeilen **ohne** `.tag(SidebarSelection.openBookings)` auf jeder Zeile (Kollision). Muster = Trip-Buchungskinder: `Button` setzt Selection-Mailbox + `selectedOpenBookingIDs`; visuelle Selektion über Highlight, nicht über mehrfach gleiches `List`-Tag. **Kein** neues `SidebarSelection.openBooking(UUID)` in v1.
4. Identifier: `UITestingIdentifiers.bookingRow` / `tripRow` weiterverwenden. Content-`OpenBookingRow` **ohne** `bookingRow`-ID. Detail-Timeline kann weiter `bookingRow` nutzen — nur eine Outline- und eine Timeline-Instanz derselben ID gleichzeitig im Tree vermeiden (offene Buchung nicht parallel unter Trip).

### Out of Scope

- iOS Tab-UI
- Domain-/Sync-Änderungen
- Ersetzen der Content-/Detail-Spalten
- Persistenter Expand-State in UserDefaults (Session-`@State` reicht, wie heute bei Reisen)

## Architektur-Entscheidung

**Gewählt: Outline-Listen parallel zu Reisen (Ansatz A).**

| Ansatz | Kurz | Urteil |
| --- | --- | --- |
| **A — Outline-Listen** | Einzelzeilen in Sidebar; elapsed Trips mit Trip-Outline; Content bleibt | **Empfohlen** — entspricht „wie Reisen“, HIG Sidebar-Outline |
| B — Nur Section-Disclosure um Aggregat | Ein Chevron um die alte Mailbox-Zeile | Verworfen — keine echte Liste |
| C — Sidebar ersetzt Content-Liste | Keine mittlere Spalte für Offen | Verworfen — bricht Mail-Layout und Multi-Select |

Verworfene Nachbar-Interpretation aus `mail-ähnliches_layout`: damaliges „Buchungen aus Sidebar entfernen“ galt der **Trip-Hierarchie-Verdoppelung**; dieses Feature fügt **Mailbox-Inhalte** als Outline hinzu und vereinheitlicht Abgelaufen mit Reisen-Expand — kein Fork der 3-Spalten-Shell.

## Handler-Trace (`live_app`)

| UI | Handler | Side-Effects |
| --- | --- | --- |
| Offene-Buchungs-Zeile Tap | `SidebarBookingOutlineFocus` → map auf `selection = .openBookings` + `selectedOpenBookingIDs` | keine Pasteboard/Sync/Persist |
| Abgelaufen-Offen Tap | Focus → `.elapsedOpenBookings` + Selection-Set | ditto |
| Trip Chevron | toggled `expandedTripIDs` | nur UI-State |
| Trip-Kind Buchung Tap | `selection = .trip` + `selectedTimelineID` | wie bestehend Reisen |
| Create-Trip-from-all (Context) | bestehender `OpenBookingCreateTripAction` | Sheet — Tour nur Existence, kein Tap auf Create außer Mutation-Task |

## Identifier-Tabelle

| Element | Identifier |
| --- | --- |
| Sidebar root | `reisen.sidebar` |
| Trip-Zeile | `tripRow(id)` |
| Buchungs-Kind / Offene-Zeile | `bookingRow(id)` |
| Delete-Trip-Menü | `deleteTripMenu` (bestehend) |

## Isolation-Grep (`live_app`, vollständig)

Vor Outer-DoD im Diff-Scope (und bei neuen UITesting-Hooks) **vollständiger** Output, keine Stichprobe:

```bash
rg -n '@AppStorage|AppStorage\(|UserDefaults\.standard|fromUserDefaults|supportDirectoryURL|NSWorkspace|EventKit|UNUserNotificationCenter|NotificationCenter\.default|VerifySeed|UITestingLaunch' \
  Sources/Reisen Sources/ReisenSharedUI Sources/ReisenAppCore
```

Jeder neue Treffer braucht `store:`/Skip/Throw bzw. Spec-Begründung. Keine neuen `UserDefaults.standard`-Sites.

## Testbarer Focus-Vertrag (Library)

`SidebarSelection` bleibt im Executable `Reisen`. Testbarer SSOT in **ReisenAppCore**:

```swift
public enum SidebarOpenBookingMailbox: Equatable, Sendable {
    case current
    case elapsed
}

public enum SidebarBookingOutlineFocus {
    public static func select(
        mailbox: SidebarOpenBookingMailbox,
        bookingID: UUID
    ) -> (mailbox: SidebarOpenBookingMailbox, selectedIDs: Set<UUID>)
}
```

ContentView mappt `mailbox` → `SidebarSelection`. Tests: `Tests/ReisenAppCoreTests`.

`sidebarOutlineBookings` Tests: `Tests/ReisenDataTests`.

## Schnittstellen-Inventar

Siehe Ledger `interfaces.inventory`. Supply/Evidence dort; Spec bestätigt:

- **entry:** drei Sidebar-Wege oben (Button-Handler, kein List-Tag-Hack)
- **neighbor:** `OpenBookingMatching` + unveränderte Content-Spalte; `sidebarOutlineBookings`
- **contract:** Identifier-Eindeutigkeit; Focus-API; Outline-Bookings-Semantik
- **capability:** keine neuen Entitlements; Isolation-Grep vollständig

## open_gaps

- Voller XCUI-Pfad für Offene Buchungen nur wenn UITesting-Seed offene Buchungen enthält; sonst Unit-Tests (Focus + `sidebarOutlineBookings`) + Identifier am Code. Review-Tour muss Seeded-Trip-Pfad nicht brechen.
- Manuelle HIG-Pixelprüfung optional.

## Akzeptanz

1. ≥1 offene Buchung → Sidebar listet sie einzeln; Tap zeigt Detail der Buchung bei `openBookings`.
2. Aggregat-einzige Zeilen unter Offen und Abgelaufen-Offen sind weg.
3. Abgelaufene Reise mit Buchungen → Chevron; Expand zeigt Kinder wie unter Reisen.
4. `bash ./Scripts/ci-test.sh` Exit 0; macOS-UI-Smokes nicht regressiv.
5. iOS unverändert.
