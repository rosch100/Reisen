# Design: App Semantik-Audit R9

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R8 (#154–#162)

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r9-airbnb-session | medium | fix | AirbnbProviderError.sessionNotEstablished + map Unauthorized |
| r9-booking-inpage-auth | high | fix | fetchInPageText → AuthenticatedFetchError; EnrichHotel/GraphQL Unauthorized rethrow |
| r9-macos-tripdetail-tz | medium | fix | Activity/Other Copy/Summary Ortszeit-SSOT |
| r9-opodo-epoch-offset | medium | fix | freeCancellationLimit: hotelOffsetSeconds nil (kein erfundenes `0`) |
| r9-check24-html-deadline | medium | fix | HTML-Deadlines ohne Offset nicht persistieren |
| r9-gyg-decode-diag | medium | fix | Decode-Fail Skip-Diag |

## Wontfix / Defer

| id | reason |
| --- | --- |
| Traveloka refund soft-401 | open-gaps wontfix Soft-Enrich |
| r9-defer-ios-remove-trip | UX Scope (Timeline Context-Menu) |
| r9-defer-booking-graphql-decode | pauschal invalidJSON — niedriger Nutzen |
| r9-defer-opodo-graphql-decode | analog |
| r9-defer-check24-catalog-try | Soft-snapshot Catalog |
| r9-defer-unsupported-enrich | emptyEnrichment default |

## DoD

Tests, ci-test, codereview, PR, Merge.
