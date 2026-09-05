# Design: App Semantik-Audit R17

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R16

## Problem

R16 hat `SDTrip.isElapsed` auf `HotelStayDate.calendar` umgestellt. Residual: `SDBooking` ListInclusion (`appearsInList` / `isUpcoming` / `isElapsed`) defaultet weiter auf `Calendar.current` — Hotel-Date-only-Anker west-of-GMT wirken fälschlich elapsed. `BookingElapsedLabel`/`Text`, Timeline-Filter und `BookingDayOverlap.elapsedCalendar` erben dasselbe. Passenger-`birthDate` im BookingEditor fehlt der HotelStayDate-Picker-Round-Trip.

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r17-booking-listinclusion-type-calendar | medium | fix | Hotel → `HotelStayDate.calendar`, sonst `.current` |
| r17-elapsed-label-type-calendar | medium | fix | `BookingElapsedText`/`Label` typbewusst |
| r17-timeline-inherits-type-calendar | medium | fix | `timelineBookings` / `sidebarChildBookings` ohne erzwungenes `.current` |
| r17-overlap-elapsed-type-calendar | medium | fix | `elapsedCalendar` nil → je `bookingType` |
| r17-birthdate-picker-roundtrip | medium | fix | DatePicker get/set über `localPickerDate` / `dateOnly` |

## Ansatz

1. `BookingType.usesHotelStayDateAnchors` / `listInclusionCalendar` (nur `.hotel`; Apply-Pfad speichert nur Hotel als Date-only).
2. `SDBooking` ListInclusion: Default-Kalender aus Typ; explizites `calendar:` bleibt Override.
3. Timeline/Overlap/Elapsed-UI: `Calendar? = nil` → typbewusst erben.
4. birthDate: Binding get `localPickerDate`, set `dateOnly`; New-Button bleibt `dateOnly(fromLocalPickerDate: Date())`.
5. Unverändert: `SyncBookingMatchIndex`, PreTravelHint (device-local Lead Times).

## DoD

Tests, Spec/Plan, kein Commit in diesem Schritt (Parent orchestriert Ship).
