# Globale Buchungs-Tagesüberschneidungen — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reiseübergreifende Overlap-Erkennung (SSOT Domain) mit Typ-Occupancy und Parität macOS + iOS inkl. Sidebar/Offen.

**Architecture:** `BookingDaySpan` (+ `tripID`, `bookingType`) und Occupancy über `BookingType.usesStayLikeOverlapEnd` (nur Hotel half-open). Counting/Suppress in Domain; Data-Helfer `countsByID(sdBookings:)`; SharedUI-Caption; Views nur Lookup.

**Tech Stack:** Swift, Swift Testing, SwiftData, SwiftUI, `HotelStayDate.calendar`.

## Global Constraints

- Spec: `docs/superpowers/specs/2026-09-01-booking-day-overlap-global-design.md`
- Default-Calendar: `HotelStayDate.calendar`
- `usesStayLikeOverlapEnd`: nur `.hotel == true`
- Multi-Room-Suppress nur gleiche non-nil `tripID` + Same-Place+Same-Dates
- Pool: `status != .cancelled`; UI nur Data-`countsByID(sdBookings:)`
- Caption: Symbol + Text + accessibilityLabel
- TDD: RED = **fachlicher Assert-Fail** auf bestehendem oder neuem API-Verhalten (nicht Compile als RED-Nachweis)
- Worktree: `.worktrees/feat-booking-day-overlap-global`
- Kein `*.xcodeproj`-Commit; kein Cursor-Co-Author

## File map

- Modify: `BookingType.swift`, `BookingDaySpan.swift`, Matching/Counting/Overlap(+Matching)
- Modify: `ModelAccessors.swift` + Data-Extension `countsByID(sdBookings:)`
- Create: `BookingOverlapCaption.swift` (+ reine Helpers testbar)
- Modify: `OpenBookingRow.swift`
- Modify: `TripDetailView.swift`, `BookingDetailContent.swift`, `ContentView.swift`
- Modify: `BookingDetailIOS.swift`, `TripDetailIOS.swift`, `OffenTab.swift`
- Modify: `BookingDayOverlapTests.swift`; Create SharedUI-Tests für Caption
- Modify: `docs/dev/feature-backlog.md`

---

### Task 1: Domain Occupancy + Counting (TDD)

**Interfaces:** `overlap-contract`, `daySpan-neighbor`

- [ ] **Step 1: Write failing behavioral tests** against Spec 1–15.
  - Zuerst Tests erweitern, die **bestehende** `countsByID`/`dayRangesOverlap`-Semantik treffen und **jetzt falsch** sind (z. B. Same-Day-Flug erwartet Count≥1 → aktuell 0; Same-Place verschiedene Trips erwartet Count → aktuell 0 wegen Always-Suppress).
  - Neue APIs (`tripID` am Span, `usesStayLikeOverlapEnd`) nur mit Asserts, die Spec treffen; Init-Signatur parallel mit Implementierung, aber RED-Nachweis über Assert, nicht „type not found“.
  - Helper `span(...)` um `tripID`/`bookingType` erweitern; Calendar `HotelStayDate.calendar`.

- [ ] **Step 2: Run** `swift test --filter BookingDayOverlap` → FAIL mit **fehlgeschlagenem Expect** (nicht nur Compile)

- [ ] **Step 3: Implement** Typ-Occupancy, Suppress, `isEligible`, Factories, Calendar-Defaults

- [ ] **Step 4: Run** → PASS

- [ ] **Step 5: Commit** `feat(domain): global booking day overlap occupancy and trip suppress`

---

### Task 2: Data `countsByID(sdBookings:)` (TDD)

**Interfaces:** `daySpan-neighbor`, `overlap-contract` (Persistenz-Bridge — **nicht** entry)

- [ ] **Step 1: Failing Data-/Bridge-Test:** `SDBooking.daySpan` trägt `trip?.id` + `bookingType`; `countsByID(sdBookings:)` droppt `.cancelled` und zählt Cross-Trip (SwiftData in-memory wie bestehende Data-Tests).

- [ ] **Step 2: Run** → Assert-FAIL

- [ ] **Step 3: Implement** daySpan + Extension

- [ ] **Step 4: PASS + Commit** `feat(data): booking overlap counts helper for SDBooking`

---

### Task 3: SharedUI Caption (TDD)

**Interfaces:** `overlap-ui-entry`

- [ ] **Step 1: Failing tests** auf reine API der Caption (ohne XCUI):
  - `BookingOverlapCaption.isVisible(overlapCount:)` → false bei 0, true bei ≥1
  - `labelText(extraCount:)` == `L10n.overlapLabel(extraCount:)`
  - accessibility-String == labelText
  - `OpenBookingRow` Init akzeptiert `overlapCount` (Compile ok; Sichtbarkeit über `isVisible`)

- [ ] **Step 2: Run SharedUI-/Domain-Filter** → Assert-FAIL

- [ ] **Step 3: Implement** `BookingOverlapCaption` + `OpenBookingRow(overlapCount:)`; Detail-Views nutzen Caption statt Text-only

- [ ] **Step 4: PASS + Commit** `feat(ui): booking overlap caption with accessibility`

---

### Task 4: macOS + iOS verdrahten + Backlog

**Interfaces:** `overlap-ui-entry` (Verdrahtung)

- [ ] **Step 1:** Global `countsByID(sdBookings:)` in TripDetailView, ContentView (Offen-Detail, Sidebar open/trip children, Listen), iOS BookingDetail/TripDetail/OffenTab; `BookingOverlapCaption` / `overlapCount` durchreichen.

- [ ] **Step 2:** `bash ./Scripts/ci-test.sh` + `bash ./Scripts/ci-build.sh --arch arm64` → PASS

- [ ] **Step 3:** Backlog-Notiz; F24 unverändert

- [ ] **Step 4: Commit** `feat: surface global booking overlaps on macOS and iOS`

---

## Ausführung

`subagent-driven-development` Tasks 1→4; Orchestrator misst RED/GREEN per Shell.
