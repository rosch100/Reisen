#+#+#+#+#+
# Flight Destination Address Storage Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store a canonical address for places scraped from CHECK24 (hotel city/venue) so destination city strings are recognized and can be reused for „Flug suchen“.

**Architecture:** We extend the domain model (`Booking`) with canonical place address fields (from/to). CHECK24 parsing will populate these fields while keeping `locationTo` as the city name. Deep-link building for flights will accept city names (not just IATA codes) by falling back gracefully when IATA extraction fails.

**Tech Stack:** SwiftUI + SwiftData + SwiftPM; CHECK24 parser (`Sources/ReisenCheck24`); deep-link builder (`Sources/ReisenCheck24/Sync/Check24DeepLinkBuilder.swift`); unit tests in `Tests/`.

## Global Constraints
- macOS SwiftUI + SwiftData models.
- No dummy/fallback values that hide data quality issues.
- Keep UI responsive; parsers fail-soft but do not silently corrupt identifiers.

---

## Task Structure
### Task 1: Extend Domain & Persistence for Address Fields

**Files:**
- Modify: `Sources/ReisenDomain/Entities/Booking.swift`
- Modify: `Sources/ReisenDomain/Entities/ProviderDrafts.swift`
- Modify: `Sources/ReisenData/Models/SwiftDataModels.swift`
- Modify: `Sources/ReisenData/Schema/ReisenSchema.swift`
- Modify: `Sources/ReisenData/Mapping/DomainMapper.swift`
- Modify: `Sources/ReisenData/Persistence/SwiftDataRepositories.swift`

**Interfaces:**
- Consumes: existing `locationFrom` / `locationTo` semantics
- Produces: new optional properties on persisted bookings

- [ ] Step 1: Add new optional address properties to the domain
  - Update `Booking` with:
    ```swift
    public var locationFromAddress: String?
    public var locationToAddress: String?
    ```
  - Update `ProviderBookingDraft` with corresponding fields.
- [ ] Step 2: Add new persisted fields to SwiftData model `SDBooking` with matching names
  - Add:
    ```swift
    public var locationFromAddress: String?
    public var locationToAddress: String?
    ```
  - Update `init(...)` and assign.
- [ ] Step 3: Bump schema version and update migrations
  - Increment `ReisenSchemaV1` → `ReisenSchemaV2` (version identifier + schema enum wiring).
  - Keep migration stages empty only if SwiftData can auto-migrate; otherwise define explicit migration.
- [ ] Step 4: Update mapper/repository apply/upsert logic
  - `DomainMapper.booking(from:)` reads new fields from `SDBooking`.
  - `SwiftDataBookingRepository.upsert/apply` writes new fields to `SDBooking`.

**Testing (after Task 1):**
- [ ] Run: `swift build --target Reisen`

### Task 2: CHECK24 Scrape -> Canonical Address for Hotels

**Files:**
- Modify: `Sources/ReisenCheck24/Parsers/ParsedActivity.swift`
- Modify: `Sources/ReisenCheck24/Parsers/ActivityListParser.swift`
- Modify: `Sources/ReisenCheck24/Sync/Check24TravelProvider.swift`

**Interfaces:**
- Consumes: CHECK24 activities JSON fields like `hotel_street`, `hotel_zipcode`, `hotel_city_name`, `hotel_country_name`
- Produces: `locationToAddress` populated; `locationTo` remains city name

- [ ] Step 1: Extend `ParsedBooking` with optional address fields.
- [ ] Step 2: In `ActivityListParser.activityLocation(from:)`, keep city as `locationTo`.
- [ ] Step 3: Add `activityAddress(from:)` that builds a canonical single-line address:
  - prefer `hotel_street`, `hotel_zipcode`, `hotel_city_name`, `hotel_country_name`
  - format as a human-readable string with commas; never invent missing parts.
- [ ] Step 4: In `Check24TravelProvider` mapping to `ProviderBookingDraft`, persist these address fields.

**Testing (after Task 2):**
- [ ] Add a focused unit test using existing HAR snapshots if feasible, or validate by parsing one sample `product_specific_data`.
- [ ] Run: `swift test --filter ActivityListParser`

### Task 3: Deep-Link „Flug suchen“ erkennt Stadtziele auch ohne IATA

**Files:**
- Modify: `Sources/ReisenCheck24/Sync/Check24DeepLinkBuilder.swift`
- Modify: `Tests/ReisenCheck24Tests/ParserTests.swift`

**Interfaces:**
- Consumes: `GapContext` where `toHint` can be a city name (e.g. „Yogyakarta“)
- Produces: flight link URL even when IATA extraction fails

- [ ] Step 1: Change `extractIATACode` to:
  - if 3-letter IATA exists → use it
  - else → fall back to sanitized city name string (non-empty) instead of throwing `missingToIATA`.
- [ ] Step 2: Add unit test:
  - input `toHint = "Yogyakarta"` returns a flight URL containing `to_0=Yogyakarta-C` (or the expected sanitized form).

**Testing (after Task 3):**
- [ ] Run: `swift test --filter deepLinkFlight`

### Task 4: UI + Booking Editor: Zeige / Pflege Adresse

**Files:**
- Modify: `Sources/Reisen/App/TripDetailView.swift`
- Modify: `Sources/Reisen/App/BookingEditor.swift`

**Interfaces:**
- Consumes: new `locationToAddress/locationFromAddress`
- Produces: UI fields display address without breaking existing label formats

- [ ] Step 1: In detail view, show city as today; optionally show address under it if available.
- [ ] Step 2: Extend `BookingEditorForm`:
  - add optional text fields for „Adresse (optional)“ that bind to `locationToAddress/locationFromAddress`.

**Testing (after Task 4):**
- [ ] Manual smoke: add a Check24 hotel, create a Zwischen-Transport gap, verify „Flug suchen“ appears.

---

## Self-Review
1. Spec coverage: tasks cover persistence, parsing, deep-links, and UI.
2. Placeholder scan: no TBDs; all values are grounded in existing parser fields.
3. Type consistency: properties match intended SwiftData field names.

