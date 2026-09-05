# App Semantik-Audit R7 Implementation Plan

> Inline execution (Nutzer: ohne Rückfragen).

**Goal:** Residual Offset-/Auth-/Decode-Semantik nach R6 schließen.

**Architecture:** Raw-ISO behalten wo Decode Offset killt; Unauthorized fail-closed; Decode-Fails diagnostizieren.

**Tech Stack:** SwiftPM, DiagnosticLogger, Swift Testing

---

### Tasks

1. GYG: `expirationDate`/`policyExpirationDate` als `String?`; Deadlines mit `ISODateTime.offsetSeconds`
2. Airbnb Experience: listingTimeZone Offset wie Stay
3. Billiger + Booking Flight/MyTrips + Airbnb Fetch: Unauthorized → Session
4. Check24 Basket + OfferFacts: decode Skip-Diag
5. Booking HTML: missing_hotel_offset Diagnostic bei Enrich
6. Tests + ci-test + PR
