# Design: App Semantik-Audit R11

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R10 (#154–#163+)
**Branch:** `audit/app-semantics-2026-09-05-r11`

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r11-booking-stage-auth | high | fix | Stage GraphQL: `sessionNotEstablished`/`sessionTokensMissing` fail-closed (kein Soft-Skip → Wipe) |
| r11-booking-timeline-auth | high | fix | Timeline-Schleife: Auth-Fehler sofort rethrow |
| r11-trip-bounds-format | medium | fix | `TripDateBounds.formattedAbbreviatedRange` via `HotelStayDate.format` (GMT), nicht `Date.formatted` |
| r11-expand-prompt-format | medium | fix | `TripPeriodExpandPrompt.formattedRange` via `HotelStayDate.format`; toter `Calendar`-Param entfernt |
| r11-trip-period-display | medium | fix | Trip-Period-UI (macOS Sidebar/Detail, iOS Tab/Detail) via `TripDateBounds`/`HotelStayDate.format`, kein Geräte-`.formatted(date:)` |
| r11-trip-editor-persist-anchor | medium | fix | `TripEditorSheet` Persist: `startDate`/`endDate` via `HotelStayDate.dateOnly(fromLocalPickerDate:)` (wie BookingEditor) |
| r11-openbooking-hotel-cal | medium | fix | `OpenBookingMatching` Defaults: `HotelStayDate.calendar` statt `.current` |
| r11-assign-hotel-cal | medium | fix | `TripBookingAssignment` Defaults: `HotelStayDate.calendar` |
| r11-create-trip-seed-cal | medium | fix | `OpenBookingCreateTripAction` seed/dateRangeText Defaults: `HotelStayDate.calendar` |
| r11-paste-assign-cal | medium | fix | `PasteImportReviewPayload.creating` Default: `HotelStayDate.calendar` |
| r11-sync-today-hotel-cal | medium | fix | `SyncProviderBookings` `startOfToday` via `HotelStayDate.calendar` |

## Wontfix / Defer (prior, unverändert)

| id | reason |
| --- | --- |
| Traveloka refund soft-401 | Soft-Enrich |
| Check24 catalog soft-snapshot | Soft-snapshot |
| Booking/Opodo GraphQL invalidJSON detail | niedriger Nutzen |
| Opodo Wall-Clock offset `0` | R1/R8 Konvention |
| iOS remove-from-trip | UX Scope |
| unsupported enrich empty | default |

## DoD

Domain- + SharedUI-Tests, ci-test, codereview, PR, Merge. Danach R12-Analyse; Loop stoppt bei CLEAN.
