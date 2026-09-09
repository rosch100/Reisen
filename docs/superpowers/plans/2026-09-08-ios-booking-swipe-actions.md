# iOS Booking Swipe Actions Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** HIG-konforme Swipe-Aktionen für Trip-Buchungen (Löschen / Von Reise entfernen) plus Policy-SSOT, die Offen-Swipes mitbenutzt.

**Architecture:** Pure `BookingRowSwipeActions` in `ReisenSharedUI` entscheidet Aktion pro Kontext×Kante. iOS-Views verdrahten `swipeActions(allowsFullSwipe: false)` und bestehende Confirm-Modifier (`bookingDeleteConfirmAlert`, Remove-Dialog). Keine Domain-/Schema-Änderung.

**Tech Stack:** SwiftUI, SwiftData, Swift Testing, `DiagnosticLogger`, L10n/`UITestingIdentifiers`

## Global Constraints

- `allowsFullSwipe: false` für alle Delete/Remove-Swipes in diesem Diff
- Confirm vor Perform; Copy-SSOT `BookingTripActions` / bestehende Modifier
- Swipe-Labels ohne `…` (`common.delete`, `common.remove`); Menü mit `…` (`actionDeleteEllipsis`, `actionRemoveFromTrip`)
- Keine Secrets/PII in Logs; Write-time Refactor-Bar; Logging+Tests im selben Diff
- iOS Build/Test nur via `Scripts/ios-*.sh` / `ci-test.sh`
- iOS-XCUI = open_gaps (Identifier trotzdem setzen)

---

### Task 1: BookingRowSwipeActions SSOT + Tests

**Files:**
- Create: `Sources/ReisenSharedUI/BookingRowSwipeActions.swift`
- Create: `Tests/ReisenSharedUITests/BookingRowSwipeActionsTests.swift`
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift` (Swipe-IDs)

**Interfaces:**
- Consumes: nichts (pure)
- Produces: `BookingRowSwipeAction`, `BookingRowSwipeEdge`, `BookingRowSwipeContext`, `BookingRowSwipeActions.actions(for:edge:)`

- [ ] **Step 1: Write the failing tests** — volle 6er-Matrix laut Spec

```swift
@Test func tripAssigned_trailingIsDeleteOnly() { /* [.delete] */ }
@Test func tripAssigned_leadingIsRemoveFromTrip() { /* [.removeFromTrip] */ }
@Test func openCompact_trailingIsDelete() {
    #expect(BookingRowSwipeActions.actions(
        for: .openBooking(offersCreateTripOnLeading: true), edge: .trailing
    ) == [.delete])
}
@Test func openSplit_trailingIsDelete() {
    #expect(BookingRowSwipeActions.actions(
        for: .openBooking(offersCreateTripOnLeading: false), edge: .trailing
    ) == [.delete])
}
@Test func openCompact_leadingCreateTrip() { /* [.createTripFromBooking] */ }
@Test func openSplit_leadingEmpty() { /* [] */ }
```

- [ ] **Step 2: Run tests — expect RED** (`swift test --filter BookingRowSwipeActions` via `ci-test` subset or xcodebuild SharedUITests)
- [ ] **Step 3: Implement minimal `BookingRowSwipeActions.swift` + Identifier-Konstanten**
- [ ] **Step 4: Run tests — GREEN**
- [ ] **Step 5: Commit** — `feat(ios): add booking row swipe policy SSOT`

---

### Task 2: TripDetailIOS Swipe + Remove Confirm + Context-Menü

**Files:**
- Modify: `Apps/ReiseniOS/Shared/TripDetailIOS.swift`
- Test: Policy bereits Task 1; manueller/ios-test Smoke; Logging Asserts optional über Diagnose-Komponente

**Interfaces:**
- Consumes: `BookingRowSwipeActions`, `bookingDeleteConfirmAlert`, Remove-Confirm (standalone oder `bookingTripConfirmDialogs`)
- Produces: Timeline-Rows mit trailing/leading Swipe; Context Remove; `removePendingFromTrip` Persistenz+Log

- [ ] **Step 1: State** — `pendingRemoveBooking`, `showRemoveFromTripConfirmation` analog Delete
- [ ] **Step 2: An Booking-Row** — nach Context-Menü: `swipeActions` trailing/leading aus Policy; **`allowsFullSwipe: false`**; Buttons:

```swift
Button(L10n.string(.commonDelete), role: .destructive) { /* pending delete */ }
    .accessibilityIdentifier(UITestingIdentifiers.swipeBookingDelete)
Button(L10n.string(.commonRemove)) { /* pending remove */ }
    .tint(.orange)
    .accessibilityIdentifier(UITestingIdentifiers.swipeBookingRemoveFromTrip)
```

- [ ] **Step 3: Context-Menü** — `actionRemoveFromTrip` vor Delete (Menü-Label mit `…`)
- [ ] **Step 4: Confirm-Modifier + `removePendingBookingFromTrip()`** mit DiagnosticLogger fail/success; Perform **nur** in Confirm-Handlern (Handler-Trace Spec)
- [ ] **Step 5: `bash ./Scripts/ios-test.sh` oder passende Suite; `ci-test.sh` wenn machbar**
- [ ] **Step 6: Commit** — `feat(ios): swipe delete/remove on trip booking rows`

---

### Task 3: OffenTab an SSOT anbinden

**Files:**
- Modify: `Apps/ReiseniOS/Shared/OffenTab.swift`

**Interfaces:**
- Consumes: `BookingRowSwipeActions` mit `.openBooking(offersCreateTripOnLeading: !usesSplit)`
- Produces: gleiches UX, keine Policy-Drift

- [ ] **Step 1: Trailing/Leading Buttons aus Policy-Array ableiten** (Verhalten unverändert)
- [ ] **Step 2: Identifier `UITestingIdentifiers.swipeBookingDelete` am Offen-Trailing-Delete**
- [ ] **Step 3: Kurz testen / ci-test Diff**
- [ ] **Step 4: Commit** — `refactor(ios): drive open-booking swipes from SSOT`

---

### Task 4: Observability/DoD-Check + Isolation-Grep

**Files:** nur Verifikation / ggf. kleine Log-Lücken

- [ ] **Step 1: Isolation-Grep** exakt Spec-Command auf Feature-Fläche — Baseline 0; Diff keine neuen Treffer
- [ ] **Step 2: Checklist** Logging+Tests Skill (`reisen-observability-tests`)
- [ ] **Step 3: `bash ./Scripts/ci-test.sh`** Exit 0
- [ ] **Step 4: Commit nur wenn Fixes nötig**

---

## DoD (Plan)

- Spec-Akzeptanz 1–7 erfüllt (inkl. Identifier)
- Ledger-Inventar: contract/entry Supply geliefert; iOS-XCUI bleibt `open_gaps`
- Outer: `/codereview`, residual refactor, CRAP gate 5
