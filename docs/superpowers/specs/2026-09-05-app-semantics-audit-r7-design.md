# Design: App Semantik-Audit R7

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R6, open-gaps (#154–#160)
**Scope:** Frische Residual-Analyse; GYG/Airbnb Offsets; Auth fail-closed; Check24 Decode-Diags; Booking HTML missing-offset Diag.

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r7-gyg-deadline-offset | high | fix | Policy-Daten als Raw-ISO; hotelOffsetSeconds aus Offset |
| r7-airbnb-exp-offset | high | fix | Experience-Enrich listingTimeZone → Facts (+ Skip-Diag) |
| r7-billiger-auth | high | fix | fetchJSON Unauthorized → sessionNotAuthenticated |
| r7-booking-flight-auth | high | fix | flightOrderJSON Unauthorized → sessionNotEstablished |
| r7-booking-mytrips-auth | medium | fix | MyTrips Unauthorized → sessionNotEstablished |
| r7-airbnb-fetch-auth | medium | fix | airbnbFetchTextAsync 401/403 → AuthenticatedFetchError |
| r7-check24-decode-diag | medium | fix | Basket + OfferFacts decode Skip-Diag |
| r7-booking-html-missing-offset | medium | fix | nil Offset + Markup → deadline_skipped Diag |

## Defer

| id | reason |
| --- | --- |
| r7-defer-schedule-display | SharedUI Geräte-TZ Display — UI-Pass |
| r7-defer-birthdate | BookingEditor Date() Binding |
| r7-defer-ios-keychain | SyncTab Message-Parität |
| r7-defer-check24-readiness | Enrich Soft bei !ready |
| r7-defer-booking-stage | GetTrips Stage Catch Diag |
| r7-defer-guest-hints | AirbnbGuestHint decode Diag |
| r7-defer-hotel-invalid-url | Booking empty enrich ohne Diag |

## DoD

Tests, `ci-test.sh`, `/codereview`, PR, Merge.
