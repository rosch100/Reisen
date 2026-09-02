# Sidebar + Listen: Mehrfachauswahl, Sync, Selection-Kontextmenü

**Datum:** 2026-09-02  
**Status:** Spec (feature-dev P1, Promote-and-Gapfill)  
**Basis:** `docs/superpowers/specs/2026-09-02-list-multi-select-context-menu-design.md` (Timeline/`List(selection:)` bleibt)  
**Scope:** macOS Sidebar-Outline + mittlere Listen; Selektionssync; Batch-Löschen über Selection-Menü.

## Intent

Nutzer:innen sollen **Reisen**, **offene Buchungen** und **abgelaufene (offene) Buchungen** sowohl **links** als auch **in der Mitte** HIG-konform mehrfach auswählen. Die Selektion ist **eine SSOT** (gemeinsame Sets) — Highlight und Kontextmenü sind in beiden Spalten **konform**. Für die Selektion gibt es ein sinnvolles Kontextmenü, mindestens **Löschen…** für alle selektierten gleichartigen Elemente (mit Confirm).

## Gap vs. Ist / Vor-Spec

| Fläche | Ist | Gap |
| --- | --- | --- |
| Mitte Offen/Abgelaufen | `List(selection: Set<UUID>)` + `forSelectionType` (Create-Trip Multi; kein Batch-Delete) | Batch-**Löschen…**; Elapsed Multi-Summary; Mailbox-Wechsel filtert Set |
| Mitte Trip-Timeline | `List(selection: Set<String>)` + Multi-Summary; Batch nur **Von Reise entfernen** | Batch-**Löschen…** zusätzlich |
| Sidebar Offen-/Abgelaufen-Zeilen | Button setzt immer `[id]`; Highlight `== [id]` | Outline-Multi-Click; Highlight `contains`; Rechtsklick-Vorauswahl |
| Sidebar Trip-Buchungskinder | Click setzt `[id]`; Highlight schon `contains` | Outline-Multi-Click; Rechtsklick-Vorauswahl |
| Sidebar Reise-Eltern | Einzel-`.tag(SidebarSelection.trip)` | `selectedTripIDs` + Multi-Summary + Batch-Trip-Delete |
| Sync links↔mitte | Sets geteilt, Sidebar schreibt/zeigt nur Einzel | Schreib-/Highlight-Parität + XCUI Sync-Evidence |

**Nicht anfassen:** iOS; Provider-Sync-Zeilen; Multi-Drag; Create-Draft-Selektion (bleibt Exclusive Single).

## Begriffe (Spec-Terms)

| Begriff | Bedeutung |
| --- | --- |
| **Selection-SSOT** | `selectedOpenBookingIDs`, `selectedTimelineIDs`, `selectedTripIDs` in `ContentView` |
| **Mailbox-Selection** | `SidebarSelection` (Navigation) — nicht das Booking-/Trip-Set |
| **Outline-Multi-Click** | Linksklick auf ungetaggte Sidebar-Button-Zeile → Replace / ⌘Toggle / ⇧Range |
| **Selection-Anchor** | Pro Domäne die ID der letzten **replace**-Auswahl. ⇧Range startet bei Anchor (fehlt/nicht in `orderedVisible` → Anchor = clicked, Range = `{clicked}`). **Toggle:** Anchor bleibt, **außer** Anchor ∉ resultierendem Set → dann `newAnchor = clicked`. Nach Toggle-des-Anchors (Remove): Anchor = `clicked` nur wenn clicked noch ∈ Set, sonst ein deterministisches verbleibendes Element (`min`) oder nil wenn Set leer wäre (Policy verhindert leer → `{clicked}`, Anchor = clicked). |
| **Visible ordered IDs** | Sichtbare Zeilen-IDs der **aktuellen Gruppe** in Anzeigereihenfolge |
| **Menu-Effective-Set** | Für Sidebar-`.contextMenu` **ohne State-Mutation im ViewBuilder**: `effective = selected.contains(clicked) ? selected : [clicked]`. Menü und Aktionen nutzen nur `effective`. Visuelle SSOT-Sets ändern sich erst bei **Linksklick** (OutlineMultiSelect) oder wenn eine Menü-**Aktion** das Set bewusst setzt (z. B. vor Batch-Confirm). Kein `prepare()`-Side-Effect im Builder; kein AppKit-`menuWillOpen` in v1. |
| **Batch-Delete** | Ein Confirm; dann geordnete Pipeline pro ID; Fail-Stop; Diagnostics |
| **Primary** | `|Set|==1` → diese ID für Detail/Portal; `|Set|>1` → Multi-Summary; Portal disabled |
| **AX isSelected** | Selektierte Sidebar-Outline-Zeilen setzen `.accessibilityAddTraits(.isSelected)` (nicht nur Hintergrundfarbe), damit XCUI Sync messbar ist |

## Architektur (Ansatz A — SSOT-Sets + Outline-Multi-Click)

**Gewählt:** Shared Sets als SSOT. Mitte: native `List(selection:)`. Sidebar-Buchungs-/Trip-Zeilen: Button-Outline (Tag-Kollision) + Outline-Multi-Click.

| Ansatz | Urteil |
| --- | --- |
| **A — Shared Sets + Outline-Multi-Click** | **Empfohlen** |
| B — Booking-Tags in `List(selection: Set<SidebarSelection>)` | Verworfen — Tag-Kollision |
| C — AppKit `NSOutlineView` | Verworfen — YAGNI |

### OutlineMultiSelect-API (AppCore)

```text
enum OutlineMultiSelectClick: replace | toggle | extendRange

func apply<ID: Hashable>(
  clicked: ID,
  current: Set<ID>,
  orderedVisible: [ID],
  anchor: ID?,
  click: OutlineMultiSelectClick
) -> (selected: Set<ID>, newAnchor: ID)
```

| click | selected | newAnchor |
| --- | --- | --- |
| replace | `{clicked}` | clicked |
| toggle | `current` symDiff `{clicked}`; wenn Ergebnis leer → `{clicked}` | siehe Selection-Anchor (Toggle-Regel oben) |
| extendRange | alle IDs von Index(anchor)…Index(clicked) inkl.; fehlen Indizes → `{clicked}` | Anchor unverändert wenn ∈ selected, sonst clicked |

Modifier-Mapping (macOS Linksklick): `shift` → extendRange (auch mit command); sonst `command` → toggle; sonst replace. Quelle: `NSEvent.modifierFlags` zum Click-Zeitpunkt.

### Trip-Eltern Multi + Primary

1. `@State selectedTripIDs: Set<UUID>`; `@State tripSelectionAnchor: UUID?`.
2. Replace-Klick Reise: `selection = .trip(id)`, `selectedTripIDs = [id]`, Anchor = id, Timeline-Reset wie Ist.
3. Toggle/Range: nur `selectedTripIDs` (+ Anchor-Regeln); `selection = .trip(primary)` wobei **Primary** = wenn `|Set|==1` das Element, sonst **Anchor wenn ∈ Set**, sonst `Set.min` nach `UUID` (deterministisch, kein „letzter Klick“-Rätsel).
4. `|selectedTripIDs|>1` → Content-Spalte **TripMultiSelectionSummary** (nicht `TripDetailView`).
5. Visuelles Highlight + **AX isSelected** auf Trip-Eltern: `selectedTripIDs.contains(trip.id)`.
6. Entfernen einer Trip-ID aus dem Set (Delete/andere Mailbox): Primary neu nach Regel 3; Set leer → Navigation Fallback wie Ist nach Trip-Delete.

### Sync- und Mailbox-Regeln

1. **Offen:** Sidebar + Mitte → nur `selectedOpenBookingIDs`. Highlight + **AX isSelected**: `selection == .openBookings && contains(id)`.
2. **Abgelaufen-Offen:** dieselbe Set-Variable, aber:
   - Beim Wechsel `selection` von `.openBookings` → `.elapsedOpenBookings` (und umgekehrt): Set auf IDs **schneiden**, die in der **Ziel**-Mailbox existieren; wenn leer → Auto-Select erste sichtbare ID der Ziel-Mailbox (Ist-Parität).
   - Detail: `|Set|>1` → Multi-Summary **auch** für Elapsed (Parität zu Offen); `|Set|==1` → Detail.
3. **Trip-Buchungen:** Sidebar + Timeline → `selectedTimelineIDs`. Trip-Fokus setzen wenn Buchungszeile angeklickt. Anchor `timelineSelectionAnchor: String?` pro aktivem Trip; bei Trip-Wechsel Anchor reset + Timeline-Set wie Ist `onChange`.
4. Domänenwechsel Trip ↔ Offen: jeweils fremde Sets leeren (`selectedTripIDs` / `selectedTimelineIDs` bzw. Open-Set) — **keine** Cross-Mailbox-Multi.
5. Create-Draft: Exclusive Single (`BookingCreateDraftSelection`).

## Rechtsklick-Lifecycle (Sidebar, verbindlich)

Ist: `.contextMenu { … }` an **Button**-Zeilen ohne List-Tag.

**Pflicht (Menu-Effective-Set, keine Builder-Mutation):**

1. Menu-Builder ist **rein**: liest `selected*`-Sets und `clicked` ID, berechnet `effective = MenuEffectiveSelection.resolve(clicked:selected:)`, baut Einträge daraus.
2. **Keine** `@State`-Writes im Builder (kein `prepare()` mit Side-Effect — kompiliert nicht bzw. rendert unsicher).
3. Destructive/Batch-**Aktionen** im Button-Action-Closure dürfen Sets setzen (z. B. `selectedOpenBookingIDs = effective` vor Confirm), weil Actions außerhalb des View-Builds laufen.
4. Unit: `MenuEffectiveSelection.resolve` — clicked ∈ Set → Set; sonst `{clicked}`.
5. XCUI Menu-Effective-Unterscheidung (**nicht** nur „Löschen…“; **nicht** „Neue Reise aus Auswahl“ — das existiert auch im Singleton):
   - Multi (clicked ∈ Set, |Set|>1): Menü hat Batch-Aktionen; **kein** Copy-/Portal-Einzelblock (Open Multi-Menü laut Vertrag nur Create-Trip + Delete).
   - Singleton Effective (clicked ∉ Set): Menü hat **Copy**-Einträge (`BookingCopyConfirmationMenuItems` / L10n copy titles) — Existence; Multi-Highlights bleiben sichtbar.

Mitte bleibt `contextMenu(forSelectionType:)` (System-Selection bereits gesetzt).

## Kontextmenü-Vertrag

### Offene / abgelaufene Buchungen

| Selektion | Einträge |
| --- | --- |
| 1× | Ist-Einzelmenü |
| ≥2 | **Neue Reise aus Auswahl**; **Löschen…**; kein Portal/Cancel auf Zufalls-ID |

### Trip-Timeline / Trip-Buchungskinder

| Selektion | Einträge |
| --- | --- |
| 1× Booking | Ist inkl. Löschen… / Von Reise entfernen |
| ≥2 nur Bookings | **Von Reise entfernen…**; **Löschen…** (`batchDeleteBooking`) |
| gemischt/Gaps | keine destruktiven Batch-Aktionen |

### Reisen

| Selektion | Einträge |
| --- | --- |
| 1× | Ist Edit / Add / Delete Trip |
| ≥2 | **Löschen…** — **eine** Policy-Wahl (`keepAsOpen` \| `deleteContained`) für **alle** selektierten Trips |

## Batch-Delete-Orchestrierung

1. Confirm einmal (Open/Timeline: Booking-Delete-Alert mit Anzahl; Trips: bestehender Trip-Delete-Dialog textlich auf Anzahl angepasst).
2. Diagnostic `result: started`, `reason: count=n`.
3. IDs in **stabiler Sortierung** (`UUID`/`String` ascending) sequentiell löschen über bestehende `BookingDeletion` / `TripDeletion`.
4. **Fail-Stop:** erster Fehler → `persistErrorMessage`, Diagnostic `failed` + `errorType`, **keine** weiteren Deletes; bereits gelöschte bleiben gelöscht; Set = noch existierende IDs der ursprünglichen Selektion.
5. Erfolg aller → Diagnostic `succeeded`; Set leeren bzw. Auto-Select Fallback der Mailbox/Trip-Liste.
6. Kein stilles Skip einzelner IDs.

Pure Orchestrator-Funktion(en) in AppCore (testbar ohne SwiftUI), UI nur Confirm + Call.

### UI→Orchestrator-Handoff (Entry-Evidence ohne Confirm-Tap in XCUI)

Thin Handler in **ReisenAppCore** (injizierbarer `deleteOne`, von ContentView aufgerufen):

```text
confirmOpenBookingBatchDelete(ids) → started → SelectionBatchDeletion.run → succeeded|failed
```

Analog Timeline/Trips. **Evidence:** Handler-Unit mit Fake-Deleter (all-success + mid-fail) im Task, der den Handler implementiert. ContentView Confirm-Buttons rufen denselben Handler auf (kein zweiter Pfad). XCUI bleibt Reach-only — kein Confirm-Tap.

### Menu-Effective vs. sichtbare Multi-Selektion (bewusst)

Rechtsklick auf unselektierte Zeile: Menü = Singleton-`effective`, **Highlights der bestehenden Multi bleiben** bis Linksklick oder committed Action. **Context-Target**-Semantik (Menü-Ziel ≠ visuelle SSOT) — absichtlich, kein AppKit-`menuWillOpen` in v1.

## Logging

| component | phase | event |
| --- | --- | --- |
| `OpenBookingList` | `selection_action` | `delete_batch` |
| `TripBookingList` | `selection_action` | `delete_batch` |
| `TripList` | `selection_action` | `delete_batch` |

`reason`: `count=\(n)` — keine Titel/PII. `result`: started/succeeded/failed.

## Tests / live_app

1. Unit `OutlineMultiSelect` + Anchor-Regeln (inkl. Toggle-des-Anchors).
2. Unit `MenuEffectiveSelection.resolve`.
3. Unit Context-Action-SSOT (multi delete).
4. Unit Batch-Orchestrator: all-success; fail-stop mid-batch; Set-Bereinigung; Diagnostic results.
5. Unit: Mailbox-Filter-Helper Offen↔Elapsed; Primary-Trip aus Set+Anchor.
6. **XCUI (Pflicht entries):**
   - **Sync Open:** ≥2 Seed-Offen → Content ⌘click zweite `bookingRow` → beide Sidebar-Zeilen `isSelected == true`.
   - **Sidebar Menu Effective:** nach Sync Multi → rightClick selected → **kein** Copy-Menütitel (Batch-Menü) → Escape; rightClick unselektierte → **Copy**-Menütitel Existence (Singleton Effective) bei weiterhin multi-highlights → Escape.
   - **Trip-Eltern Multi:** Seed ≥2 Trips → Sidebar ⌘click zweite `tripRow` → Multi-Summary Identifier Existence (`tripMultiSelectionSummary`) → kein Delete-Confirm.
   - **Timeline Batch-Delete Reach:** Seed ≥2 Trip-Buchungen → Multi → Menü Reach Delete-Titel + Escape (Handler-Unit belegt Handoff).
7. Isolation: vollständiger Grep; keine neuen Defaults-Sites.

### Isolation-Grep (vollständig)

```bash
rg -n '@AppStorage|AppStorage\(|UserDefaults\.standard|fromUserDefaults|supportDirectoryURL|NSWorkspace|EventKit|UNUserNotificationCenter|NotificationCenter\.default|VerifySeed|UITestingLaunch' \
  Sources/Reisen Sources/ReisenSharedUI Sources/ReisenAppCore
```

P1-Baseline: viele bestehende Sites (bekannt aus Vor-Spec). Dieses Feature: keine neuen Sites ohne `store:`/Skip/Throw/Spec-Begründung.

## Handler-Trace (`live_app`)

| Journey-Schritt | Handler (Ist/Soll) | Smoke Side-Effect? |
| --- | --- | --- |
| Sidebar Offen Linksklick | `outlineOpenBookingClick` → `OutlineMultiSelect.apply` → Sets | nein |
| Mitte Offen ⌘Klick | `List(selection:)` Binding | nein — Sync-Assert Sidebar `isSelected` |
| Sidebar Rechtsklick | Menu-Effective-Set (rein) → Action darf Set setzen | Reach-only Menütitel |
| Confirm Batch-Delete | Orchestrator + Deletion APIs | **nicht** in Smoke |
| Trip-Eltern Multi | `selectedTripIDs` + Summary | nein |

## Identifier

- Sidebar / Offen-Zeile: `bookingRow(id)`
- Timeline: `timelineBookingRow(id)`
- Delete-Menü Buttons: `deleteBookingMenu` / `deleteTripMenu` wo Button-basiert; Selection-Menü Reach über L10n-Titel wenn System `menuAction:` setzt
- Trip Multi-Summary Root: `reisen.trip.multi-selection-summary` (`UITestingIdentifiers.tripMultiSelectionSummary`)

## Out of Scope / open_gaps

- iOS Edit-Mode / Multi
- Multi-Drag (F16)
- Cross-Mailbox-Selektion (Offen + Trip gleichzeitig)
- Persistenz der Selection über Neustart
- Range über Section-Grenzen hinaus
- Provider-Sync-Zeilen Multi
- ~~XCUI ⌘Multi~~ — **nicht** open_gap; Sync-/Menu-/Trip-Multi-XCUI sind Pflicht

## Schnittstellen-Inventar

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| outline-multi-click | contract | `OutlineMultiSelect` + Modifier-Mapping | `OutlineMultiSelectTests` |
| menu-effective-set | contract | `MenuEffectiveSelection.resolve` | Unit |
| selection-sync-open | entry | Shared Set + Sidebar AX `isSelected` | XCUI ⌘Multi Mitte→Sidebar |
| sidebar-context-menu-effective | entry | Right-Click Effective-Set Menü | XCUI Batch- vs Einzel-Titel Reach |
| selection-sync-trip-bookings | entry | Shared `selectedTimelineIDs` + AX | XCUI Timeline⌘↔Sidebar (Seed ≥2) |
| trip-parent-multi | entry | `selectedTripIDs` + Summary Identifier | XCUI ⌘ zweite Trip-Zeile → Summary |
| batch-delete-orchestrator | contract | AppCore Orchestrator Fail-Stop | Unit all-success + mid-fail |
| batch-delete-open | entry | Confirm-Handler → Orchestrator | **Handler-Unit Fake-Deleter** (selber Task wie UI-Wire) + XCUI Reach |
| batch-delete-timeline | entry | Confirm-Handler → Orchestrator | **Handler-Unit** + XCUI Timeline Multi Menu Reach |
| batch-delete-trips | entry | Confirm-Handler → Orchestrator | **Handler-Unit** + XCUI Trip-Multi Summary/Delete Reach |
| live-app-isolation | capability | Vollständiger Grep; keine neuen Defaults-Sites | Grep-Output im Measure |
| live-app-identifiers | contract | `bookingRow`≠`timelineBookingRow`; `tripMultiSelectionSummary` | Identifier-Unit |
| live-app-assert-vs-act | entry | Smoke Reach-only; Sync ohne Confirm | MacUISmokeTests |
| live-app-window-scope | neighbor | Main Window Page Object | bestehend MacUI |
| live-app-uitest-compile | neighbor | UITest-Target Imports laut Ist | Compile UI tests |
| live-app-test-hooks | neighbor | `UITestingLaunch` Isolation Suite | bestehender Bootstrap; keine neuen globalen Hooks |

## Akzeptanz

1. Offen ≥2: ⌘Klick Mitte und Sidebar zeigen dieselben Selection-Highlights; Detail Multi-Summary; Elapsed analog.
2. Mailbox Offen↔Elapsed: Set gefiltert auf Ziel-Mailbox.
3. Rechtsklick unselektierte Sidebar-Zeile → Einzelmenü; Rechtsklick in Multi-Selektion → Batch-Menü inkl. Löschen….
4. Trip-Buchungen Multi Timeline↔Sidebar sync; Menü Remove + Delete Batch.
5. ≥2 Reisen: Multi-Summary; eine Policy löscht alle.
6. Batch Fail-Stop + Diagnostics; `ci-test.sh` + `macos-ui-test-remote.sh` grün.
