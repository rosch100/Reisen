# Opodo Flight Passengers & Baggage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist structured Opodo flight passengers and their baggage allowances end-to-end (HAR/GraphQL → domain → SwiftData → UI).

**Architecture:** Wir führen neue Domain-Entities für Passagiere und Gepäck ein und spiegeln sie als SwiftData-Modelle mit 1:1 Beziehungen unter `SDBooking`. Enrichment für Flugbuchungen befüllt diese Felder aus `getTripByToken` (Passagiere) und `baggageInfo` (Gepäck). Beim Sync werden Passagiere/Gepäck je Booking per Replace-Strategy vollständig ersetzt, analog zu Deadlines.

**Tech Stack:** Swift 6, SwiftData, Swift Testing, WKWebView/GraphQL über bestehende Provider-Session.

## Global Constraints
- macOS SwiftUI + SwiftData + SwiftPM
- Keine Dummy/Fallback-Werte: Daten fehlen → Optional oder leere Listen; keine „stillen“ Ersetzungen
- TDD: Neue Verhalten werden mit Swift Testing Tests abgedeckt
- SSOT: Mapping/Join-Logik nur an einer Stelle
- Keine Workarounds statt richtiger Lösung
---

### Task 1: Domain-Modell erweitern (Passagiere/Gepäck)

**Files:**
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/Entities/Booking.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/Entities/ProviderDrafts.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/Entities/BookingRateDetails.swift`
- Add: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/Entities/FlightPassengers.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/Entities/BookingEnums.swift`

**Interfaces:**
- Consumes: bestehende `Booking`/`ProviderBookingDraft`/`ProviderBookingEnrichment`
- Produces: neue Typen `BookingPassenger`, `BaggageAllowance`, Enums `TravellerType`, `BaggageType`

- [ ] **Step 1: Write the failing test**
  - Create: `/Users/roschmac/Entwicklung/Reisen/Tests/ReisenDomainTests/FlightPassengersMappingTests.swift`
  - Erwartung: Domain-Typen sind equatable und enthalten die neuen Felder (kompilierbar + Basic Construction).
- [ ] **Step 2: Run test to verify it fails**
  - `cd /Users/roschmac/Entwicklung/Reisen && swift test --filter FlightPassengersMappingTests -v`
  - Expected: FAIL (Typen existieren noch nicht).
- [ ] **Step 3: Write minimal implementation**
  - Implement new structs/enums and add `passengers: [BookingPassenger]` to `Booking` plus matching fields in Provider drafts/enrichment.
- [ ] **Step 4: Run tests and make sure they pass**
  - Erwartung: PASS.
- [ ] **Step 5: Commit**

### Task 2: SwiftData Schema V3 + Modelle + Mapper

**Files:**
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenData/Schema/ReisenSchema.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenData/Models/SwiftDataModels.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenData/Mapping/DomainMapper.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenData/Persistence/SwiftDataRepositories.swift`

**Interfaces:**
- Consumes: neue Domain-Entities
- Produces: `SDBookingPassenger`, `SDBaggageAllowance` plus Persist/Load in Mapper & Repository

- [ ] **Step 1: Write the failing test**
  - Extend: `/Users/roschmac/Entwicklung/Reisen/Tests/ReisenDataTests/SchemaTests.swift`
  - Erwartung: Schema V3 bootet; `Booking` → SwiftData → Domain roundtrip enthält Passagiere/Gepäck.
- [ ] **Step 2: Run test to verify it fails**
  - `swift test --filter SchemaTests -v`
- [ ] **Step 3: Write minimal implementation**
  - Implement new SwiftData @Model classes with relationships and update schema definitions to V3.
  - Update repositories to persist passengers & baggage.
  - Replace-Strategy: Vor dem Setzen bestehender Passagiere/Gepäck für ein Booking alle bisherigen Kinder löschen.
- [ ] **Step 4: Run tests and make sure they pass**
- [ ] **Step 5: Commit**

### Task 3: Opodo Enrichment erweitert (getTripByToken + baggageInfo)

**Files:**
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenOpodo/OpodoTripCancellationGraphQL.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenOpodo/OpodoTravelProvider.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenOpodo/OpodoTripsGraphQLParser.swift`
- Add: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenOpodo/OpodoFlightPassengersGraphQL.swift`

**Interfaces:**
- Consumes: Opodo HAR GraphQL payloads
- Produces: `ProviderBookingEnrichment.passengers` für `bookingType == .flight`

- [ ] **Step 1: Write the failing test**
  - Add: `/Users/roschmac/Entwicklung/Reisen/Tests/ReisenOpodoTests/OpodoFlightPassengersGraphQLTests.swift`
  - Fixtures:
    - `getTripByToken` Flight travellers payload (aus HAR) minimal
    - `baggageInfo` payload minimal (numPassenger + baggageList types/pieces/weight)
  - Expect: Parser liefert 3 passengers und 3 baggageAllowances (pro Pax) mit weightKg nil bei -1.
- [ ] **Step 2: Run test to verify it fails**
- [ ] **Step 3: Write minimal implementation**
  - Implement Opodo parsers for travellers and baggageInfo responses.
  - Wire into `OpodoTravelProvider.enrichBooking` for flight bookings.
- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

### Task 4: SyncStore & SyncProviderBookings Persistieren (Replace-Strategy)

**Files:**
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/Reisen/Stores/SyncStore.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenDomain/UseCases/SyncProviderBookings.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/ReisenData/Persistence/SwiftDataRepositories.swift`

**Interfaces:**
- Consumes: `ProviderBookingEnrichment.passengers`
- Produces: `SwiftDataBookingRepository` writes passengers/baggage

- [ ] **Step 1: Write failing test**
  - Extend `/Users/roschmac/Entwicklung/Reisen/Tests/ReisenDomainTests/SyncProviderBookingsUpsertTests.swift`
  - Erwartung: Upsert replace passengers list (alte löschen, neue einfügen), auch wenn booking.tripID vorhanden ist.
- [ ] **Step 2: Run test**
- [ ] **Step 3: Implement minimal changes**
  - Update draft enrichment merge strategy: when enrichment provides passengers, overwrite existing.
- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

### Task 5: UI minimal integrieren (TripDetail + BookingEditor)

**Files:**
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/Reisen/App/TripDetailView.swift`
- Modify: `/Users/roschmac/Entwicklung/Reisen/Sources/Reisen/App/BookingEditor.swift`

**Interfaces:**
- Consumes: `Booking.passengers`
- Produces: read-only listing of passengers + baggage in detail view; editor still shows old fields but optionally reflects derived passengerCount from passengers count.

- [ ] **Step 1: Write failing test**
  - Minimal compile-time: keine SwiftUI tests; Fokus auf Kompilieren via `swift test`.
- [ ] **Step 2: Run test**
- [ ] **Step 3: Implement minimal UI**
  - Add sections in `TripDetailView` and `BookingEditor` for displaying passenger names and baggage allowance summary.
- [ ] **Step 4: Run tests**
- [ ] **Step 5: Commit**

