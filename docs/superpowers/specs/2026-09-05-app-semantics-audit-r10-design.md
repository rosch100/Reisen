# Design: App Semantik-Audit R10

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen, Loop bis CLEAN)
**Vorgänger:** R1–R9 (#154–#163)

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r10-booking-tokens-missing | high | fix | `sessionTokensMissing` vor HTML-Fallback fail-closed (kein Sync-Wipe) |
| r10-opodo-epoch-parse | medium | fix | `parseISODate` Epoch → offset `nil` (kein erfundenes `0`) |
| r10-trip-window-hotel-cal | medium | fix | TripDateBounds/Window/Expand Default = `HotelStayDate.calendar` |

## Wontfix / Defer (unverändert)

| id | reason |
| --- | --- |
| Traveloka refund soft-401 | Soft-Enrich |
| Check24 catalog soft-snapshot | Soft-snapshot |
| Booking/Opodo GraphQL invalidJSON detail | niedriger Nutzen |
| Opodo Wall-Clock offset `0` | R1/R8 Konvention |
| iOS remove-from-trip | UX Scope |
| unsupported enrich empty | default |

## DoD

Tests, ci-test, codereview, PR, Merge. Danach R11-Analyse; Loop stoppt bei CLEAN.
