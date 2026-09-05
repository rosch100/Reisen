# Design: App Semantik-Audit R12

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R11
**Branch:** `audit/app-semantics-2026-09-05-r12`

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r12-booking-graphql-canceled | high | fix | Trip-XP `canceled` auf `GetTrip`/`GraphQLTrip` decode; `true` → `statusRaw` `CANCELLED` (schlägt `reservationStatus` CONFIRMED); GetTrips-IDs mit `canceled:true` skippen; Timeline-Drafts via DraftAssembler aus aktivem Katalog |
| r12-check24-policy-offset | medium | fix | `CancellationPolicyParser`: Offset via Label/`cancelableUntilHotel`/ISO `offsetSeconds(from:)` auf hotelUntil/utcUntil; ohne Offset keine Deadline |
| r12-airbnb-scheduled-offset | medium | fix | Stay Scheduled-Events: `hotelOffsetSeconds` durch Parser/Cancellation; ohne Listing-Offset Deadline droppen (nicht nil persistieren) |

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

BookingCom GraphQL-Tests (`canceled:true` + CONFIRMED → cancelled), Check24/Airbnb Offset-Deadline-Tests, ci-test, codereview, PR, Merge. Danach R13-Analyse; Loop stoppt bei CLEAN.
