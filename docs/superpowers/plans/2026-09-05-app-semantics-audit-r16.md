# App Semantik-Audit R16 Implementation Plan

> Spec: `docs/superpowers/specs/2026-09-05-app-semantics-audit-r16-design.md`

**Branch:** `audit/app-semantics-2026-09-05-r16`

## Tasks

1. [x] `TripEditorSheet` Period-Expand Confirm → `localPickerDate`
2. [x] `TripDetailView.saveEditor` Hotel-Draft Anchors vor `proposalIfNeeded`
3. [x] `TripEditorAssignmentPreviewSection` Trip aus `dateOnly(fromLocalPickerDate:)`
4. [x] `LocalEventKitBridge.allDaySpan` für `tripStart`/`tripEnd` → `hotelStayRange`
5. [x] `SDTrip.isElapsed` / `listGapBadgeCount` Default `HotelStayDate.calendar`
6. [x] Unit-Tests (Expand/Picker, Mixed-Anchors, EventKit-Span, isElapsed West-of-GMT)
7. [x] Spec/Plan
8. [ ] `bash ./Scripts/ci-test.sh` / Codereview / PR (Parent)
