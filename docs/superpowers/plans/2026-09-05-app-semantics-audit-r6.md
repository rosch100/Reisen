# App Semantik-Audit R6 Implementation Plan

> **For agentic workers:** Inline execution in this session (Nutzer: ohne Rückfragen).

**Goal:** Residual Deadline-Offset- und Session-Semantik nach frischer Analyse schließen.

**Architecture:** Provider/Domain behalten bekannten Offset; Auth-Fails fail-closed; PasteImport wall-clock an HotelStayDate-SSOT.

**Tech Stack:** SwiftPM, DiagnosticLogger, Swift Testing

## Global Constraints

- Kein `TimeZone.current` / Offset `0` erfinden
- Unauthorized → Provider Session-Error
- Tests + Logging im Diff

---

### Task 1: Booking.com Flug-Deadline-Offset

**Files:**
- Modify: `Sources/ReisenBookingCom/BookingComFlightOrderMapping+Deadlines.swift`
- Test: `Tests/ReisenBookingComTests/ParserTests.swift` (oder neuer gezielter Test)

- [ ] `hotelOffsetSeconds: ISODateTime.offsetSeconds(from: raw)` setzen
- [ ] Test mit ISO `+0700` / `Z`

### Task 2: Airbnb Activity Deadline-Offset

**Files:**
- Modify: `Sources/ReisenAirbnb/AirbnbActivityReservationDetailsParser.swift`
- Test: `Tests/ReisenAirbnbTests/ParserTests.swift`

- [ ] `parseCancelByDate` liefert Date+TimeZone; Deadline setzt `secondsFromGMT`
- [ ] Assert in Enrichment-Test `hotelOffsetSeconds != nil` (WIB/Jakarta)

### Task 3: Flight Normalizer Deadline-Fill

**Files:**
- Modify: `Sources/ReisenDomain/Services/BookingFlightTimeNormalizer.swift`
- Test: `Tests/ReisenDomainTests/BookingTimeNormalizerDeadlinesTests.swift`

- [ ] Bei nil Deadline-Offset: `flightDepartureOffsetSeconds` übernehmen
- [ ] Test Flug mit dep-Offset und Deadline ohne Offset

### Task 4: Check24 Baggage Auth + Opodo Flight Auth

**Files:**
- Modify: `Sources/ReisenCheck24/Sync/Check24TravelProvider+Enrich.swift`
- Modify: `Sources/ReisenOpodo/OpodoTravelProvider.swift`
- Test: Check24/Opodo Tests wo möglich; sonst Gate-Assert über bestehende Auth-Guard-Muster

- [ ] Check24: Unauthorized in baggage catch → throw `sessionNotEstablished`
- [ ] Opodo `enrichFlightBooking`: wrap Unauthorized → `sessionNotEstablished`
- [ ] Soft baggage fail: Completion nicht reines `.succeeded` wenn baggage_failed (reason oder `.skipped`)

### Task 5: PasteImport Ticket TZ

**Files:**
- Modify: `Sources/ReisenPasteImport/PasteImportTicketDate.swift`
- Test: PasteImport-Tests

- [ ] `formatter.timeZone = HotelStayDate.timeZone`
- [ ] Test wall-clock unabhängig von Geräte-TZ

### Task 6: Verify + Ship

- [ ] `bash ./Scripts/ci-test.sh`
- [ ] `/codereview` → Fix medium+
- [ ] Commit, PR, Merge
