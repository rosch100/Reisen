# Implementation-Plan: Activity-Sync (Airbnb + GetYourGuide)

Status: **Phase 0–2 implementiert** (Unit-Tests gegen redigierte Fixtures).  
Spec-Index: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) (Abschnitt Spec-Index).

## Phase 0 — [`BookingType.activity`](booking-type-activity-impl-spec.md) ✅

1. Enum + exhaustive Switches + Tests
2. UI-Labels (Editor, Listen, Schedule-Felder)
3. `ci-test` / `ios-test` grün

**Done when:** `.activity` durchgängig wählbar/anzeigbar; bestehende Buchungen unverändert.

## Phase 1 — [Airbnb Experiences](airbnb-experiences-impl-spec.md) ✅

1. Catalog: `EXPERIENCE_RESERVATION` → `.activity` (Feldmapping in Airbnb-Spec)
2. Optional: `travelerCapacity` schon im Draft
3. Parser `AirbnbActivityReservationDetailsParser` (Rows by `id` — Airbnb-Spec)
4. `enrichBooking`: Experience-Branch → `activity_reservation_details`; Stay unverändert
5. Tests gegen `docs/fixtures/provider-research/airbnb_*`

**Done when:** Experience-Sync liefert Titel/Treffpunkt/Preis/Storno/Gäste; Stay-Regression grün.

## Phase 2 — [GetYourGuide](getyourguide-impl-spec.md) ✅

1. SPM-Target `ReisenGetYourGuide` + `ProviderID.getYourGuide` + Registry/Logo/iOS-Liste
2. `__INITIAL_STATE__`-Extractor + Catalog-Parser (`myBookings` — GYG-Spec)
3. Enrichment-Parser (`bookingSummary` — GYG-Spec)
4. `TravelProvider` fetchCatalog / enrichBooking (Cookie-Session)
5. Tests gegen `gyg_*_redacted.json`

**Done when:** Upcoming GYG-Activities als `.activity` Drafts + sinnvolles Enrichment.  
Merge nach Phase 0; parallel zu Phase 1 vorbereitbar.

## Phase 3+ (nicht Teil der Activity-Arbeit)

1. Check24 productKey Live-Audit ([Checkliste](check24-productkey-audit.md)) — Keys erfasst 2026-08-28; `rentalcar` gemappt; HTML-Detail-Parser angebunden
2. Expedia Trips HAR + Spec
3. Viator / Gap-Deep-Links (Skyscanner/Kayak/GYG-Suche)
4. Opodo optional TZ/ISO (nur mit Wall-Clock-Tests)

## Explizit nicht

- Partner-/Demand-APIs
- Opodo Muss-Änderungen aus der August-HAR
- Produktivcode ohne die Specs oben
