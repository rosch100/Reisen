# App Semantik-Audit R12 Implementation Plan

> Inline (ohne Rückfragen).

**Goal:** Booking.com GraphQL-Feld `canceled` (Trip-Ebene) decode und als Storno behandeln; Deadline-Pfade ohne Stay-/Listing-Offset nicht persistieren.

1. `canceled: Bool?` auf `GetTrip` und `GraphQLTrip` (DTOs)
2. `catalogStatusRaw(reservationStatus:tripCanceled:)` — bei `tripCanceled` Token `CANCELLED`
3. Timeline-Parser: `trip.canceled` an Draft-Mapper; GetTrips: IDs mit `canceled:true` skippen
4. Tests: inline JSON `canceled:true` + `reservationStatus` CONFIRMED → cancelled (kein confirmed Katalog-Draft); GetTrips-Skip
5. Check24 `CancellationPolicyParser`: Offset aus Label/Hotel-Until bzw. `ISODateTime.offsetSeconds(from:)` auf hotelUntil/utcUntil; ohne Offset → Deadline droppen + Tests
6. Airbnb Scheduled-Events: `hotelOffsetSeconds` durch Parser/Cancellation verdrahten; ohne Offset → nil return; TravelProvider Offset vor Parse; Tests
7. Spec/Plan R12; kein Commit in diesem Schritt
