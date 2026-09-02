# List Multi-Select + Selection Context Menu Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Trip-Timeline auf macOS erhält HIG-Mehrfachauswahl (`List(selection:)`) und listenkonformes `contextMenu(forSelectionType:)`; Offene-Buchungen-Muster bleibt.

**Architecture:** Selection-SSOT als `Set<String>` in `ContentView`; reine Helper/Aktionsvertrag-Types in SharedUI; `TripDetailView.bookingsList` wird List ohne Button-Wrapper; Batch-Remove mit Confirm + DiagnosticLogger.

**Tech Stack:** SwiftUI macOS, SwiftData (`SDBooking`/`SDTrip`), ReisenSharedUI, ReisenDiagnostics, XCUI `ReisenMacUITests`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-02-list-multi-select-context-menu-design.md`
- Keine Domain-Port-Erfindung: Remove = bestehende `trip = nil` / Assign-Pipeline
- Logging Pflicht auf Batch-Pfad (`TripBookingList` / `selection_action`) — Factory im **App-Target** `Sources/Reisen/App/`
- Tests + Identifier im selben Diff; Smoke Reach-only (kein Confirm-Tap)
- Timeline-Identifier: `timelineBookingRow` (nicht `bookingRow`)
- Portal-Commands nur bei `|selectedTimelineIDs|==1` Booking
- Isolation-Grep: keine neuen Defaults-Sites; Plan-Task prüft Diff
- Write-time Refactor-Bar; kein Parallel-HIG (kein Custom Cmd/Shift auf ScrollView)
- iOS / Sidebar-Multi / Batch-Hard-Delete = out of scope

---

### Task 1: TimelineSelection + Context-Action SSOT (TDD)

**Files:**
- Create: `Sources/ReisenSharedUI/TimelineSelection.swift`
- Create: `Sources/ReisenSharedUI/TripTimelineContextActions.swift`
- Create: `Tests/ReisenSharedUITests/TimelineSelectionTests.swift`
- Create: `Tests/ReisenSharedUITests/TripTimelineContextActionsTests.swift`

**Interfaces:**
- Consumes: `TripTimelineItem` IDs als `String`; Gap-IDs mit Prefix `gap|`
- Produces:
  - `enum TimelineSelection { static func primaryID(in: Set<String>) -> String? }` — nur bei count==1
  - `enum TripTimelineSelectionKind { case empty; case singleBooking; case singleGap; case multipleBookingsOnly; case mixedOrGapsOnly }`
  - `enum TripTimelineContextActions { static func kind(...); static func actions(for:) -> Set<…> }`

- [ ] **Step 1: Write failing tests** for `primaryID`: empty→nil; one→that; many→nil

- [ ] **Step 2: Run filter TimelineSelectionTests — RED**

- [ ] **Step 3: Implement** `TimelineSelection.primaryID`

- [ ] **Step 4: GREEN**

- [ ] **Step 5: Write failing tests** for context actions: singleBooking contains remove+delete; multipleBookingsOnly contains batchRemove only (no delete); mixed → no destructive batch

- [ ] **Step 6: Implement** `TripTimelineContextActions` + GREEN

- [ ] **Step 7: Commit** `test: TimelineSelection and trip timeline context action SSOT`

---

### Task 2: Diagnostic contract for batch remove (TDD)

**Files:**
- Create: `Sources/Reisen/App/TripBookingListDiagnostics.swift` (**App-Target**, nicht SharedUI — SharedUI hat keine direkte Diagnostics-Dependency)
- Create: `Tests/ReisenTests/TripBookingListDiagnosticsTests.swift` (oder vorhandenes App-Test-Target; falls keins: kleinstes passendes Target laut Package.swift)
- Modify: call sites in Task 4

**Interfaces:**
- Produces: `TripBookingListDiagnostics.removeFromTripBatch(result:count:errorType:)` → `DiagnosticEvent` mit `component: "TripBookingList"`, `phase: "selection_action"`, `event: "remove_from_trip_batch"`, `reason` enthält count

- [ ] **Step 1: Failing test** asserts event fields

- [ ] **Step 2: Implement factory** + GREEN

- [ ] **Step 3: Commit** `feat: diagnostic events for trip booking list batch remove`

---

### Task 3: ContentView Selection-Set Binding + Portal Vertrag

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift` (`selectedTimelineIDs: Set<String>`; `selectedPortalBooking` nur bei count==1)
- Modify: `Sources/Reisen/App/TripDetailView.swift` (Binding-Typ)

**Interfaces:**
- Consumes: `TimelineSelection.primaryID`
- Produces: `$selectedTimelineIDs`; Portal `nil` wenn Multi/Gap

- [ ] **Step 1: Replace state** `@State private var selectedTimelineIDs: Set<String> = []`

- [ ] **Step 2: Update all read/write sites** inkl. `selectedPortalBooking` (nur `|Set|==1` + `UUID(uuidString:)`)

- [ ] **Step 3: Update TripDetailView** Binding + `selectTimelineID` → `[id]`

- [ ] **Step 4: Compiler check**

- [ ] **Step 5: Commit** `refactor: trip timeline selection as Set for multi-select`

---

### Task 4: TripDetailView List + Selection Context Menu + Multi Summary

**Files:**
- Modify: `Sources/Reisen/App/TripDetailView.swift` (`bookingsList`, `timelineItemIdentifier` → `timelineBookingRow`, detail multi, batch remove, `deleteBookingMenu` am Timeline-Delete)
- Create (optional): `Sources/ReisenSharedUI/TripBookingMultiSelectionSummary.swift`
- Wire: `TripBookingListDiagnostics` on batch start/success/fail

**Interfaces:**
- Consumes: Task 1–2, existing remove/delete confirms

- [ ] **Step 1: Replace ScrollView** with `List(selection:)` + tags + `contextMenu(forSelectionType:)`

- [ ] **Step 2: Multi-Summary** when count > 1

- [ ] **Step 3: Batch remove** + diagnostics

- [ ] **Step 4: Single-item menu parity** + `accessibilityIdentifier(UITestingIdentifiers.deleteBookingMenu)` on delete

- [ ] **Step 5: `bash ./Scripts/ci-build.sh --arch arm64`**

- [ ] **Step 6: Commit** `feat: HIG multi-select and selection context menu on trip timeline`

---

### Task 5: Identifiers + XCUI Smoke Reach + Isolation-Grep

**Files:**
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift` — `timelineBookingRow`, `seededTimelineBookingRow`
- Modify: `Tests/ReisenSharedUITests/UITestingIdentifiersTests.swift`
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift` — neue Timeline-Menü-Smoke; `testBookingRowOpensInspector` auf Timeline-ID umstellen

**Interfaces:**
- Handler-Trace Reach-only; queries scoped to detail/timeline

- [ ] **Step 1: Add identifiers + unit assert** `timelineBookingRow != bookingRow`

- [ ] **Step 2: XCUI** `testTripTimelineBookingContextMenu` — seeded trip, `timelineBookingRow`, rightClick, `deleteBookingMenu`, Escape

- [ ] **Step 3: Update** `testBookingRowOpensInspector` to use timeline identifier

- [ ] **Step 4: Isolation-Grep** auf Diff — keine neuen Defaults-Sites; Output ins Ledger `measure_notes`

- [ ] **Step 5: Run** `bash ./Scripts/macos-ui-test.sh` then `bash ./Scripts/ci-test.sh`

- [ ] **Step 6: Commit** `test: XCUI reach for trip timeline selection context menu`

---

## Self-Review (Plan)

- Spec-Terms inkl. Primary (count==1), Timeline-Booking-Identifier, Gap-Prefix
- Diagnostics im App-Target
- live_app: Isolation-Grep Task, Identifier-Split, Reach-only, Portal single-only
- Logging Task 2+4
