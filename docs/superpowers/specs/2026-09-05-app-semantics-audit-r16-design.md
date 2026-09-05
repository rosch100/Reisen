# Design: App Semantik-Audit R16

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R15

## Problem

R15 hat Editor-Load auf `localPickerDate(fromStored:)` umgestellt. Residual: Period-Expand-Confirm und Assignment-Preview schreiben bzw. vergleichen noch GMT-Anker als DatePicker-Werte; Hotel-Create in `TripDetailView` mischt Picker-Lokalwerte mit Trip-GMT bei `proposalIfNeeded`; EventKit Trip-Grenzen lesen Y/M/D über Hotel-Civil-TZ statt HotelStayDate-SSOT; `SDTrip.isElapsed` / `listGapBadgeCount` defaulten auf `Calendar.current` (West-of-GMT Tagesverschiebung).

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r16-tripeditor-expand-confirm-picker | medium | fix | Confirm: Proposal → `localPickerDate` vor Persist |
| r16-period-expand-hotel-draft-mixed-anchors | medium | fix | Create: Hotel-Draft vor Expand auf `dateOnly(fromLocalPickerDate:)` |
| r16-tripeditor-assign-preview-localpicker | medium | fix | Preview-Trip aus Picker via `dateOnly(fromLocalPickerDate:)` |
| r16-trip-boundary-eventkit-gmt | medium | fix | `tripStart`/`tripEnd` All-day → `hotelStayRange` |
| r16-trip-elapsed-device-calendar | medium | fix | `isElapsed` / `listGapBadgeCount` Default `HotelStayDate.calendar` |

## Ansatz

1. `TripEditorSheet` Confirm setzt Picker-State aus Proposal-GMT-Ankern über `HotelStayDate.localPickerDate`.
2. `TripDetailView.saveEditor` Create: bei `.hotel` Anchors konvertieren, bevor `proposalIfNeeded` Trip-GMT vergleicht.
3. `TripEditorAssignmentPreviewSection`: Draft-`Trip` mit GMT-Ankern aus Picker-Daten.
4. `LocalEventKitBridge.allDaySpan`: `.tripStart`/`.tripEnd` wie `.hotelStay` über `CalendarAllDaySpan.hotelStayRange`; Offset bleibt für Eligibility/Notes.
5. `SDTrip` Completeness/ListInclusion: Default-Kalender = `HotelStayDate.calendar`.
6. Tests: Expand-Confirm Round-Trip, Mixed-Anchors Expand, EventKit-Span, `isElapsed` West-of-GMT.

## DoD

Tests, Spec/Plan, kein Commit in diesem Schritt (Parent orchestriert Ship).
