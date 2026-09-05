# Design: App Semantik-Audit R8

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R7 (#154–#161)

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r8-check24-readiness | high | fix | Car !ready → throw; Hotel !ready → Completion `.skipped` |
| r8-opodo-html-offset | medium | fix | ISO-Snippet behält Offset; Wall-Clock weiter `0` |
| r8-schedule-display | medium | fix | BookingScheduleRangeText + Assign + Gaps Ortszeit-SSOT |
| r8-ios-keychain | medium | fix | SyncTab Insert-Fail Message + Diag |
| r8-booking-stage-auth | medium | fix | Stage Unauthorized rethrow; Skip-Diag sonst |
| r8-booking-catalog-auth | medium | fix | GraphQL Unauthorized → session vor HTML-Fallback |
| r8-guest-hint-diag | medium | fix | AirbnbGuestHint decode Skip-Diag |
| r8-hotel-url-diag | medium | fix | invalid_confirmation_url enrich_skipped |
| r8-car-decode-diag | medium | fix | CpInitial decode Skip-Diag |
| r8-birthdate | medium | fix | kein `Date()` im Binding-get |

## Defer

| id | reason |
| --- | --- |
| r8-defer-airbnb-session-enum | AuthenticatedFetchError reicht fail-closed; dediziertes Enum optional |
| r8-defer-inpage-hotel-fetch | EnrichHotel in-page 401 — separat |

## DoD

Tests, ci-test, codereview, PR, Merge.
