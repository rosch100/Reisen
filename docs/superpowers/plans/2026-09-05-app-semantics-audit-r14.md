# App Semantik-Audit R14 Implementation Plan

> Spec: `docs/superpowers/specs/2026-09-05-app-semantics-audit-r14-design.md`

**Branch:** `audit/app-semantics-2026-09-05-r14`

**Goal:** GetTrips-Cancel-Filter nicht durch HTML-`preferredTripIDs` aushebeln.

## Tasks

### W0

- [x] Spec + Plan

### W1

- [x] `BookingComTripIDOrdering.mergePreferredTripIDs` (pure)
- [x] `resolveTripIDs` nutzt Merge bei non-empty GetTrips; empty → preferred Fallback
- [x] Unit-Tests `BookingComTripIDOrderingTests`

### W2 (HTML-Cancel)

- [x] `r14-booking-html-cancel` → **DEFER** (keine stabile Cancel-Evidenz in My-Trips-HTML/HAR; Spec-Detail)

### W3

- [x] `bash ./Scripts/ci-test.sh`
- [x] Codereview (`looks_good`)
- [ ] PR + Merge → R15 CLEAN-Probe
