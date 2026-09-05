# Design: App Semantik-Audit R6

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen, autonome Entscheidung)
**Vorgänger:** R1–R5, open-gaps (#154–#159)
**Scope:** Frische Residual-Analyse; Deadline-/Session-Offsets und Soft-Success ohne Offset-Erfindung.

## Problem

Nach R1–R5/open-gaps bleiben Residual-Bugs: bekannte TZ/Offsets an Deadlines verworfen; Check24 Baggage-Unauthorized soft-success; Flug-Normalizer füllt Deadline-Offsets nicht; PasteImport wall-clock mit Geräte-TZ.

## Ziele (dieser Pass)

1. Booking.com Flug-Fristen: `hotelOffsetSeconds` aus ISO-Offset
2. Airbnb Activity-Cancel: `hotelOffsetSeconds` aus geparster Policy-TZ
3. Flug-/Zug-Normalizer: Deadline-Offset aus `flightDepartureOffsetSeconds` füllen (kein `0`/Geräte-TZ)
4. Check24 Flight-Baggage: Unauthorized → `sessionNotEstablished`; Soft-Fail nur Nicht-Auth
5. Opodo Flight-Enrich: Unauthorized → `sessionNotEstablished` (Parität Hotel)
6. PasteImport Ticket-Datum: `HotelStayDate.timeZone` statt `Calendar.current`

## Nicht-Ziele / Defer

| id | reason |
| --- | --- |
| r6-defer-gyg-offset | Decode verwirft Offset; braucht Raw-ISO am Policy-DTO |
| r6-defer-schedule-display | SharedUI `BookingScheduleRangeText`/Gaps Geräte-TZ — größerer UI-Pass |
| r6-defer-ios-keychain-msg | SyncTab vs macOS Message — Shell-UX |
| r6-defer-ios-remove-trip | Timeline Context-Menu Parität |
| r6-defer-booking-stage-catch | GetTrips Stage-IDs Diagnostic |
| r6-defer-check24-offerfacts | OfferFacts/Basket/Car decode Diags (R5-Muster, Batch) |
| r6-defer-airbnb-exp-listing-tz | Experience-Enrich listingTimeZone → Facts |
| r6-defer-birthdate-picker | BookingEditor `Date()` Binding |
| open-gaps wontfix | unverändert |

## Policies

- Bekannten Offset **nicht verwerfen**; fehlenden **nicht erfinden**.
- Unauthorized (401/403) → Session-Error, kein Soft-Success.
- Logging + Tests im Diff.

## Finding-Ledger R6

| id | severity | status | notes |
| --- | --- | --- | --- |
| r6-booking-flight-deadline-offset | high | fix | ISO → hotelOffsetSeconds |
| r6-airbnb-activity-deadline-offset | high | fix | Policy-TZ → hotelOffsetSeconds |
| r6-flight-normalizer-deadline | medium | fix | dep Offset → Deadlines |
| r6-check24-baggage-auth | high | fix | Unauthorized throw |
| r6-opodo-flight-auth | medium | fix | Unauthorized map |
| r6-pasteimport-ticket-tz | medium | fix | HotelStayDate.timeZone |
| r6-defer-* | — | defer | siehe Nicht-Ziele |

## DoD

Semantik-Tests, `ci-test.sh`, `/codereview`, PR, Merge.
