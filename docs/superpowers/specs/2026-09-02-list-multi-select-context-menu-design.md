# Listen: Mehrfachauswahl + listenkonformes Kontextmenü (macOS HIG)

**Datum:** 2026-09-02  
**Status:** Spec (feature-dev P1)  
**Scope:** macOS Content-/Trip-Buchungslisten. Sidebar-Outline und iOS bewusst begrenzt (siehe Out of Scope).

## Intent

Nutzer:innen sollen in **Buchungslisten** der mittleren Spalte **HIG-konform mehrfach auswählen** (Klick, ⇧Klick, ⌘Klick) und ein **listenkonformes Kontextmenü** erhalten, das auf der **aktuellen Selektion** operiert (`contextMenu(forSelectionType:)`), nicht nur auf der angeklickten Zeile.

## Ist-Zustand

| Fläche | Selektion | Kontextmenü | Bewertung |
| --- | --- | --- | --- |
| Offene Buchungen / Abgelaufen (Content) | `List(selection: Set<UUID>)` | `contextMenu(forSelectionType: UUID.self)` | **Muster** — beibehalten |
| Trip-Timeline (`TripDetailView.bookingsList`) | `ScrollView` + `Button`, `selectedTimelineID: String?` (einzeln) | Zeilen-`.contextMenu { }` | **Lücke** — kein Multi, kein Selection-Menü |
| Sidebar-Outline | Navigation `SidebarSelection?` | Zeilen-Menüs (F19) | Navigation — Multi nicht Ziel |
| iOS `OffenTab` | Edit-Mode `multiSelection` nur für Trip-Create | Zeilen-Menüs | Out of Scope v1 |

Historie: F18/F19 (Backlog-Archiv) decken Offene-Buchungen + Zuordnen ab. Timeline-Kontextmenüs (2026-07) sind Zeilen-basiert und ersetzen kein Selection-API.

## Begriffe (Spec-Terms)

| Begriff | Bedeutung |
| --- | --- |
| **Content-Buchungsliste** | Mittlere Spalte: Offene Buchungen **oder** Trip-Timeline |
| **Selection-Set** | `Set` der selektierten Zeilen-IDs (`UUID` offen; `String` Timeline-Item-IDs) |
| **Primary Selection** | Nur wenn `|Set|==1`: diese eine ID; sonst `nil` (kein „letzte Einzelwahl“ — `Set` ist ungeordnet). Detail bei `nil` und `|Set|>1` = Multi-Summary |
| **Selection-Context-Menu** | `.contextMenu(forSelectionType:)` am `List` — Menüinhalt hängt vom Set ab |
| **Batch-sichere Aktion** | Aktion, die für alle selektierten **Buchungen** sinnvoll ist (z. B. von Reise entfernen); keine stillen No-Ops auf Gaps |
| **Timeline-Item-ID** | `TripTimelineItem.id`: Booking = `UUID.uuidString`; Gap = `ComputedGap.timelineItemID` mit Prefix `gap\|…` (keine Kollision mit Booking-UUIDs) |
| **Timeline-Booking-Identifier** | `UITestingIdentifiers.timelineBookingRow(id)` — **nicht** `bookingRow` (Sidebar behält `bookingRow`) |

## Anforderungen

### 1. Trip-Timeline → native List + Mehrfachauswahl

1. `bookingsList` wird von `ScrollView`/`Button` auf **`List(selection:)`** mit **`Set<String>`** (Timeline-Item-IDs) umgestellt.
2. Zeilen: `TimelineRowLabel` + `.tag(item.id)` — **kein** `Button`-Wrapper (Ursache früherer Tap-Verzögerung in List).
3. Gesten: System-Standard (Einfachklick ersetzt Set; ⇧ erweitert Bereich; ⌘ toggelt).
4. Visuelles Selection-Highlight = System-List (kein manuelles `accentColor.opacity`-Background mehr nötig).
5. Accessibility-Identifier: Booking-Zeilen der Timeline = **`timelineBookingRow(id)`** (neu). Sidebar/Offen behalten `bookingRow(id)`. Gap-Zeilen = `reisen.gap.<item.id>` (Ist). Damit höchstens ein Element pro ID im Tree.
6. Auto-Select erste Buchung beim Trip-Wechsel bleibt: Set = `{firstBookingTimelineID}` wenn leer und Items existieren.

### 2. Selection-Binding SSOT

1. `ContentView` hält `@State selectedTimelineIDs: Set<String>` (ersetzt `selectedTimelineID: String?`).
2. Helper (SharedUI): `TimelineSelection.primaryID(in: Set) -> String?` — `|Set|==1` → dieses Element; sonst `nil`.
3. Alle bisherigen Schreibstellen (Sidebar-Trip-Buchung, Delete/Remove, Auto-Select) setzen das Set explizit (`[id]` bzw. entfernen ID), kein stilles Leeren ohne Regel.
4. Detailspalte Trip: `|Set|==1` und Item ist Booking/Gap → bestehendes Detail; `|Set|>1` → **Multi-Summary** (Anzahl + Batch-CTAs).
5. **Portal-Commands** (`selectedPortalBooking` / Open+Cancel): analog Offene Buchungen nur bei `|selectedTimelineIDs|==1` und parsebarer Booking-UUID; Multi oder Gap → `nil` / Commands disabled — kein stiller Pick „irgendeiner“ aus dem Set.

### 3. Selection-Context-Menu (Trip)

Menü über `contextMenu(forSelectionType: String.self)`:

| Selektion | Einträge |
| --- | --- |
| Genau 1× Booking | Wie heutiges Einzelmenü (Bearbeiten, Hinzufügen…, Copy, Portal, Cancel, Von Reise entfernen, Löschen…) |
| Genau 1× Gap | Wie heute (Lücke bearbeiten…, Buchung hinzufügen…) |
| ≥2, nur Bookings | Batch: **Von Reise entfernen…** (Confirm einmal für alle); optional kein „Löschen…“-Batch in v1 |
| ≥2, gemischt Booking+Gap oder nur Gaps | Kein Batch-Remove; höchstens „Buchung hinzufügen…“ wenn fachlich sinnvoll — sonst leeres/minimales Menü ohne destruktive Schein-Aktionen |
| Leer | Kein Menüinhalt |

Confirm für Batch-Remove: ein Dialog mit Anzahl; danach `assignBooking(..., toTripID: nil)` / bestehende Remove-Pipeline **pro ID**, Fehler sichtbar (`persistErrorMessage`), kein stilles Überspringen ohne Log.

### 4. Offene Buchungen — Parität halten

1. Bestehende `List(selection: $selectedOpenBookingIDs)` + `forSelectionType` **nicht** regressieren.
2. Multi (`|Set|>1`): mindestens **Reise aus Auswahl** (Ist); Einzelmenü unverändert über `openBookingContextMenuItems`.
3. Kein Zwang, Sidebar-Outline auf Multi umzustellen.

### 5. Logging

Beobachtbare Batch-Pfade über `DiagnosticLogger` / `DiagnosticEvent`:

- `component`: `TripBookingList` (SSOT-Name)
- `phase`: `selection_action`
- `event`: `remove_from_trip_batch` | `context_menu_presented` (optional localDebug)
- `result`: started / succeeded / failed
- `reason`: z. B. `count=\(n)` (keine PII/Titel)

### 6. Tests / live_app

1. Unit: Selection-Helper (Primary aus Set); Menü-Aktionsvertrag — analog `SidebarEntryContextActions`.
2. XCUI Smoke: Trip öffnen → **`timelineBookingRow(seed)`** in Detail-Scope; Context-Menu Reach (rightClick) zeigt Menüeintrag mit Identifier (z. B. `deleteBookingMenu` am Timeline-Menü verdrahtet); Escape; **kein** Confirm-Tap.
3. Bestehende Smokes, die Timeline-Buchungen über `bookingRow`/`seededBookingRow` ansteuern (`testBookingRowOpensInspector`), auf `timelineBookingRow` / `seededTimelineBookingRow` umstellen.
4. Identifier-Unit: `timelineBookingRow` ≠ `bookingRow`.

## Architektur-Entscheidung

**Gewählt: Ansatz A — Native `List(selection:)` + `contextMenu(forSelectionType:)`.**

| Ansatz | Kurz | Urteil |
| --- | --- | --- |
| **A — SwiftUI List Selection** | Trip-Timeline wie Offene Buchungen; kein Button in Rows | **Empfohlen** — HIG, ein Muster, System-Gesten |
| B — ScrollView + Custom Cmd/Shift | Behält Workaround; eigenes Selection-Chrome | Verworfen — Parallel-HIG, fehleranfällig |
| C — AppKit `NSTableView` Bridge | Maximale List-Treue | Verworfen — YAGNI, Schichtbruch |

Verworfene Angst „List verzögert Klicks“: galt für **Button in List-Zellen**; Selection-Tags ohne Button sind das Offene-Buchungen-Muster und der HIG-Weg.

## Handler-Trace (`live_app`)

| Journey-Schritt | Handler | Side-Effect in Smoke? |
| --- | --- | --- |
| Trip-Zeile Sidebar klicken | `selection = .trip` | nein (Navigation) |
| Timeline-Zeile klicken | `selectedTimelineIDs` Update | nein |
| Rechtsklick Einzel-Booking | Selection-Menü → Existence Menü-Identifier | **Reach-only** — Escape, kein Confirm |
| Batch Remove Confirm | `confirmRemove` Batch + Diagnostics | nur Mutationstest, nicht Smoke |
| Portal-Command bei Multi | `selectedPortalBooking == nil` | disabled — kein Open/Cancel |

## Identifier-Tabelle

| Element | Identifier |
| --- | --- |
| Sidebar / Offen-Buchungszeile | `bookingRow(id)` (unverändert) |
| Trip-Timeline Booking-Zeile | `timelineBookingRow(id)` (**neu**) |
| Trip-Timeline Gap-Zeile | `reisen.gap.<item.id>` |
| Delete-Buchung Menü (Sidebar + Timeline) | `deleteBookingMenu` |

## Isolation-Grep (`live_app`, vollständig)

Vor Outer-DoD im Diff-Scope **vollständiger** Output (keine Stichprobe):

```bash
rg -n '@AppStorage|AppStorage\(|UserDefaults\.standard|fromUserDefaults|supportDirectoryURL|NSWorkspace|EventKit|UNUserNotificationCenter|NotificationCenter\.default|VerifySeed|UITestingLaunch' \
  Sources/Reisen Sources/ReisenSharedUI Sources/ReisenAppCore
```

**P1-Baseline (2026-09-02, Worktree):** viele `@AppStorage` ohne `store:` in `ContentView`/`TripDetailView`/`SyncView`/`SettingsView`/iOS; `UserDefaults.standard` in AppCore/iOS Sync; `supportDirectoryURL` in Persistence/Crash. XCUI: `UITestingIsolationModifier` → `defaultAppStorage(UITestingLaunch.isolatedDefaults)`.

**Dieses Feature:** keine neuen `@AppStorage`-/`UserDefaults.standard`-/`supportDirectoryURL`-Sites. Jeder **neue** Diff-Treffer braucht `store:`/Skip/Throw oder Spec-Begründung. Bestehende Sites außerhalb Diff = known neighbor, nicht Scope dieses Features (kein Repo-weites AppStorage-Rewrite).

## Out of Scope / open_gaps

- iOS Edit-Mode-Erweiterung über Trip-Create hinaus
- Sidebar-Outline Mehrfachauswahl
- Multi-Drag (F16)
- Batch-Löschen (Hartlöschen) mehrerer Buchungen in v1
- Persistenz der Selection über App-Neustart

## Schnittstellen-Inventar

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| trip-timeline-multi-select | entry | `List(selection: Set)` Trip-Timeline | Helper-Unit + XCUI `timelineBookingRow` |
| trip-timeline-selection-context-menu | entry | `contextMenu(forSelectionType:)` + Aktionsvertrag; Reach-only Smoke | Unit Aktions-SSOT + XCUI Menü Existence + Escape |
| open-bookings-selection-menu-parity | neighbor | Bestehende Open-List unverändert | Regression Smoke/ci-test |
| selection-diagnostics | contract | DiagnosticEvents Batch-Remove in **App-Target** | Unit auf Event-Felder |
| portal-commands-single-only | neighbor | Portal nur bei `|Set|==1` Booking | Unit/Compile-Pfad `selectedPortalBooking` |
| live-app-isolation | capability | Keine neuen Defaults-Sites; XCUI `uiTestingIsolation` | Isolation-Grep Diff-Scope Exit 0 / kein neuer Treffer ohne Vertrag |
| live-app-identifiers | contract | `timelineBookingRow` ≠ `bookingRow`; Smoke scoped | Identifier-Unit + XCUI |
| live-app-assert-vs-act | entry | Smoke Reach-only (kein Confirm/Persist) | MacUISmokeTests Handler-Trace |

## Akzeptanz

1. In einer Reise mit ≥2 Buchungen: ⌘Klick wählt zwei Timeline-Zeilen; Detail zeigt Multi-Summary.
2. Rechtsklick bei Mehrfach-Buchungsselektion: Menü „Von Reise entfernen…“; Confirm entfernt alle selektierten Buchungen von der Reise.
3. Einzel-Rechtsklick behält bisherige Aktionen.
4. Offene-Buchungen-Multi und Create-Trip-from-Selection unverändert grün.
5. `ci-test.sh` + `macos-ui-test.sh` grün; neue Asserts treffen Spec-Semantik.
