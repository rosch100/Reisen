# Sidebar Open/Elapsed Expandable Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** macOS-Sidebar zeigt „Offene Buchungen“ und „Abgelaufen“ als Outline-Listen wie „Reisen“ (Einzelzeilen; elapsed Trips mit Expand und korrekten Kinderbuchungen).

**Architecture:** Testbare SSOT in Libraries (`ReisenAppCore` Focus-Mailbox, `ReisenData` `sidebarOutlineBookings`). UI in `Sources/Reisen/App`. Content-/Detail unverändert Mail-Muster. List-Tags: **keine** mehrfachen `.tag(.openBookings)` — Button-Fokus wie Trip-Kinder.

**Tech Stack:** SwiftUI, SwiftData-Models, Swift Testing, `UITestingIdentifiers`.

## Global Constraints

- macOS-Sidebar only; iOS `OffenTab` nicht anfassen
- Keine stillen Fallbacks; keine zweite Open-Matching-Logik
- `allowsAddBooking: false` für elapsed Trip-Outline
- Isolation-Grep vollständig laut Spec (nicht nur `.standard`)
- Worktree: `.worktrees/feat-sidebar-open-elapsed-expandable`
- Tests: `bash ./Scripts/ci-test.sh`; nach Sidebar-Wire auch `bash ./Scripts/macos-ui-test.sh`

---

### Task 1: `SidebarBookingOutlineFocus` (TDD, ReisenAppCore)

**Files:**
- Create: `Sources/ReisenAppCore/SidebarBookingOutlineFocus.swift`
- Create: `Tests/ReisenAppCoreTests/SidebarBookingOutlineFocusTests.swift`

**Interfaces:**
- Consumes: `Foundation.UUID`
- Produces:
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

- [ ] **Step 1: Stub so tests compile, assert fails (fachliches RED)**

```swift
// Sources/ReisenAppCore/SidebarBookingOutlineFocus.swift
import Foundation

public enum SidebarOpenBookingMailbox: Equatable, Sendable {
    case current
    case elapsed
}

public enum SidebarBookingOutlineFocus {
    public static func select(
        mailbox: SidebarOpenBookingMailbox,
        bookingID: UUID
    ) -> (mailbox: SidebarOpenBookingMailbox, selectedIDs: Set<UUID>) {
        (mailbox, []) // absichtlich falsch für RED
    }
}
```

```swift
import Foundation
import Testing
@testable import ReisenAppCore

struct SidebarBookingOutlineFocusTests {
    @Test func selectCurrentReturnsSingletonSelection() {
        let id = UUID()
        let result = SidebarBookingOutlineFocus.select(mailbox: .current, bookingID: id)
        #expect(result.mailbox == .current)
        #expect(result.selectedIDs == [id])
    }

    @Test func selectElapsedReturnsSingletonSelection() {
        let id = UUID()
        let result = SidebarBookingOutlineFocus.select(mailbox: .elapsed, bookingID: id)
        #expect(result.mailbox == .elapsed)
        #expect(result.selectedIDs == [id])
    }
}
```

- [ ] **Step 2: Run targeted tests — expect Assert FAIL (nicht Compile-Fail)**

```bash
swift test --filter SidebarBookingOutlineFocusTests
```

Expected: Tests run, `#expect` fails on empty `selectedIDs`.

- [ ] **Step 3: Fix implementation**

```swift
public static func select(
    mailbox: SidebarOpenBookingMailbox,
    bookingID: UUID
) -> (mailbox: SidebarOpenBookingMailbox, selectedIDs: Set<UUID>) {
    (mailbox, [bookingID])
}
```

- [ ] **Step 4: Same filter — PASS**

- [ ] **Step 5: Commit**

```bash
git add Sources/ReisenAppCore/SidebarBookingOutlineFocus.swift Tests/ReisenAppCoreTests/SidebarBookingOutlineFocusTests.swift
git commit -m "feat(sidebar): testable outline focus for open/elapsed mailboxes"
```

---

### Task 2: `sidebarOutlineBookings` (TDD, ReisenData)

**Files:**
- Modify: `Sources/ReisenData/Models/SDTrip+Timeline.swift` (oder neues `SDTrip+SidebarOutline.swift`)
- Create: `Tests/ReisenDataTests/SidebarOutlineBookingsTests.swift`

**Interfaces:**
- Consumes: `resolvedBookings`, `timelineBookings()`, `BookingStatus`
- Produces:
  ```swift
  func sidebarOutlineBookings(
      isElapsed: Bool,
      now: Date = Date(),
      calendar: Calendar = .current
  ) -> [SDBooking]
  ```
  - `isElapsed == false` → `timelineBookings(now:calendar:)`
  - `isElapsed == true` → non-cancelled `resolvedBookings`, sorted by `startAt`

- [ ] **Step 1: Write failing tests** (fixtures mit past provider booking assigned to elapsed trip — `timelineBookings` leer, `sidebarOutlineBookings(isElapsed: true)` enthält sie; current path equals timeline). Nutze bestehende Test-Helper/In-Memory SwiftData wenn vorhanden; sonst Domain-äquivalent auf `BookingListInclusion` spiegeln nur wenn SDTrip-Fixture zu schwer — **bevorzugt echte SDTrip-API**.

- [ ] **Step 2: Run — fachliches RED**

- [ ] **Step 3: Implement `sidebarOutlineBookings`**

- [ ] **Step 4: PASS + Commit**

```bash
git commit -m "feat(data): sidebarOutlineBookings for current vs elapsed trips"
```

---

### Task 3: Shared Trip-Outline + Offene-Buchungs-Zeilen (UI)

**Files:**
- Create: `Sources/Reisen/App/SidebarTripOutline.swift`
- Create: `Sources/Reisen/App/SidebarOpenBookingOutlineRow.swift`
- Modify: `Sources/Reisen/App/ContentView.swift`

**Interfaces:**
- Consumes: `SidebarBookingOutlineFocus`, `sidebarOutlineBookings(isElapsed:)`, `expandedTripIDs`
- Produces: Offene Liste; Reisen nutzt shared Outline mit `allowsAddBooking: true`

**Tag-Strategie (locked):** Keine `.tag(.openBookings)` auf Outline-Zeilen. Button:

```swift
Button {
    let focused = SidebarBookingOutlineFocus.select(mailbox: .current, bookingID: booking.id)
    selection = focused.mailbox == .current ? .openBookings : .elapsedOpenBookings
    selectedOpenBookingIDs = focused.selectedIDs
} label: { SidebarOpenBookingOutlineRow(booking: booking, systemImage: "calendar.badge.plus") }
.buttonStyle(.plain)
.accessibilityIdentifier(UITestingIdentifiers.bookingRow(booking.id))
```

Visuelles Highlight wenn `selectedOpenBookingIDs.contains(booking.id) && selection == .openBookings` (analog Trip-Kinder).

- [ ] **Step 1:** Extrahiere Reisen-Trip-Block nach `SidebarTripOutline` (`allowsAddBooking: Bool`, `bookings: [SDBooking]`, Expand-Binding, Callbacks).

- [ ] **Step 2:** `currentTrips` → `SidebarTripOutline(..., bookings: trip.sidebarOutlineBookings(isElapsed: false), allowsAddBooking: true)`.

- [ ] **Step 3:** Offene Section Aggregat → `ForEach(openBookings)` mit Focus-Button; Context „aus allen“ am Section-Header.

- [ ] **Step 4:** `bash ./Scripts/ci-test.sh` → 0

- [ ] **Step 5: Commit**

```bash
git commit -m "feat(sidebar): open-booking outline rows; shared trip outline"
```

---

### Task 4: Abgelaufen angleichen + Evidence

**Files:**
- Modify: `Sources/Reisen/App/ContentView.swift`
- Ledger Isolation-Grep-Output

- [ ] **Step 1:** Aggregat entfernen; `ForEach(elapsedOpenBookings)` mit `mailbox: .elapsed` + Icon `calendar.badge.clock`.

- [ ] **Step 2:** `ForEach(elapsedTrips)` → `SidebarTripOutline(..., bookings: trip.sidebarOutlineBookings(isElapsed: true), allowsAddBooking: false)`.

- [ ] **Step 3:** `bash ./Scripts/ci-test.sh` → 0

- [ ] **Step 4:** `bash ./Scripts/macos-ui-test.sh` → 0

- [ ] **Step 5:** Vollständiger Isolation-Grep (Spec-Befehl); Output in Ledger `measure_notes`. Keine neuen unsicheren Sites.

- [ ] **Step 6:** Commit

```bash
git commit -m "feat(sidebar): elapsed open rows and expandable elapsed trips"
```

---

## Spec coverage

| Spec | Task |
| --- | --- |
| Focus-API testbar AppCore | 1 |
| sidebarOutlineBookings SSOT | 2 |
| Offene Einzelzeilen, kein Aggregat, Tag-Strategie | 3 |
| Context aus allen | 3 |
| Abgelaufen-Offen + elapsed Outline + allowsAddBooking false | 4 |
| Isolation-Grep / UI smoke | 4 |

## Plan self-review

- Task 1 RED = Assert, Target = ReisenAppCoreTests
- Elapsed Bookings nicht mehr `timelineBookings` allein
- Tag-Kollision entschieden (kein per-row mailbox tag)
- allowsAddBooking für elapsed fest
