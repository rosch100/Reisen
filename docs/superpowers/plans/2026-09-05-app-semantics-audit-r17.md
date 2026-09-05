# App Semantik-Audit R17 Implementation Plan

> Spec: `docs/superpowers/specs/2026-09-05-app-semantics-audit-r17-design.md`

**Branch:** `audit/app-semantics-2026-09-05-r17`

## Tasks

1. [x] `BookingType.usesHotelStayDateAnchors` / `listInclusionCalendar`
2. [x] `SDBooking+ListInclusion` typbewusste Defaults
3. [x] `SDTrip.timelineBookings` / `sidebarChildBookings` ohne erzwungenes `.current`
4. [x] `BookingElapsedText` / `BookingElapsedLabel` typbewusst
5. [x] `BookingDayOverlap` Elapsed je `bookingType` (nil = typbewusst)
6. [x] BookingEditor birthDate DatePicker Round-Trip
7. [x] Unit-Tests (Hotel isElapsed West-of-GMT, birthDate Round-Trip, Typ-Kalender)
8. [x] Spec/Plan
9. [x] R18 follow-up: `civilDay(fromISO:)` + Opodo birthDate Ingest
10. [x] R18 follow-up: `OpenBookingMatching` typbewusster Default-Kalender
11. [ ] `bash ./Scripts/ci-test.sh` / Codereview / PR (Parent)
