# Implementation-Spec: Airbnb Experiences → `BookingType.activity`

Status: **Implementiert** (Unit-Tests gegen redigierte Fixtures).  
Phase: [`provider-activity-implementation-plan.md`](provider-activity-implementation-plan.md) Phase 1.  
HAR-Befunde: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § A.2.  
Fixtures: [`../fixtures/provider-research/airbnb_*.json`](../fixtures/provider-research/).

## Ziel

Experiences als eigene Buchungsart synchronisieren und Enrichment über die HAR-belegte Details-API liefern (Titel, Treffpunkt, Preis, Storno, Gäste).

## Voraussetzungen

1. Domain: [`BookingType.activity`](booking-type-activity-impl-spec.md) (+ UI).
2. Bestehender Katalogpfad bleibt: `AirbnbTravelProvider.fetchCatalog` → `TripListQuery`.

## Catalog (`TripListQuery`)

**Heute:** `EXPERIENCE_RESERVATION` → `bookingType: .other`  
([`AirbnbTripsGraphQLParser`](../../Sources/ReisenAirbnb/AirbnbTripsGraphQLParser.swift)).

**Soll:**

| Feld | Quelle | Aktion |
|------|--------|--------|
| `bookingType` | `schedulableType == EXPERIENCE_RESERVATION` | `.activity` |
| `confirmationCode` | `activityReservation.confirmationCode` | unverändert |
| `startAt` / `endAt` | Trip `startTime`/`endTime` + TZ | unverändert |
| `title` | Trip `displayName` | interim Ortstitel ok; Enrich überschreibt |
| `externalUrl` | `…/trips/v1/{id}/ro/EXPERIENCE_RESERVATION/{code}` | unverändert |
| `cancellationUrl` | `…/experience_alteration/{code}?flow=oneCancel&productType=experience` | HAR `app_url` Cancel-Row; Host `AirbnbAPI.baseURL` |
| `status` | Trip `UPCOMING` / cancel | `confirmed` / `cancelled` |
| Gäste | `travelerCapacity.numberOfAdults` | optional schon im Draft setzen |

## Enrichment-Branch

**Heute:** immer `TripDetailsQuery` + `/api/v2/scheduled_events/{type}/{code}`  
([`AirbnbTravelProvider.enrichBooking`](../../Sources/ReisenAirbnb/AirbnbTravelProvider.swift)).  
Für Experiences setzt Stay-orientiertes Enrichment Gäste bewusst auf `nil` (`ReservationDetails` / Activity-Init in [`AirbnbTripDetailsParser`](../../Sources/ReisenAirbnb/AirbnbTripDetailsParser.swift)).

**Soll:** wenn `schedulableType == EXPERIENCE_RESERVATION`:

1. Primär: `GET /api/v2/activity_reservation_details/EXPERIENCE_RESERVATION/{confirmationCode}`  
   Query analog Stay-RO: `locale`, `currency`, `include_header_action_rows=true`, `_format=for_generic_ro`.
2. Stay-Pfad (`scheduled_events`) unverändert für Hotels.
3. `TripDetailsQuery` optional behalten (TZ/Status), aber Experience-Titel/Preis/Storno/Gäste aus Details-Rows.

## Neuer Parser

`AirbnbActivityReservationDetailsParser` — Rows **nach `id`**, nicht nach EN-Text:

| Row `id` | Mapping |
|----------|---------|
| `dynamic_marquee_title_image_v3` | `title` (+ optional Subtitle) |
| `starts_at_ends_at_new_split_kicker` | Start/Ende (Fallback, wenn Catalog-Zeiten fehlen) |
| `event_location` / `map` | `locationTo` / `locationToAddress`, Koordinaten |
| `guest_count` | Gäste / Passengers |
| `cancel_policy` | Freitext → `cancellationDeadline` (Parse „cancel by …“) oder Policy-Text |
| `payment_summary` | Preis + Währung |
| `pdp` | Experience-Web-URL |
| `confirmation_code` | Validierung |

Kein Hotel-Check-in/out für Activities; Event-Zeitfenster reicht.

## Tests

- Fixture `airbnb_TripListQuery_experience_redacted.json` → Draft `.activity`
- Fixture `airbnb_activity_reservation_details_redacted.json` → Enrichment-Felder
- Regression: Stay-Enrichment unverändert

## Nicht in Scope

- Partner-APIs
- Past Experiences: optional. Live `PastTripsListQuery` (`first: 50`, Konto-Beleg 2026-08-28) hatte nur `RESERVATION2_CHECKIN`, keine `EXPERIENCE_RESERVATION`.
- Locale-spezifische Textparser ohne Row-`id`

## Stay Pre-Travel-Hints

Stay-Detail (`GET /api/v2/stay_reservation_details/RESERVATION2_CHECKIN/{code}`, gleicher Row-Vertrag wie Legacy `scheduled_events`) enthält sichtbare Rows `house_rules` und `house_manual`. `AirbnbGuestHintParser` mappt nur diese Rows **nach `id`**, und nur wenn `BookingGuestHintPrepKeywords` im sichtbaren Text trifft (kein Dummy). Fetch braucht den öffentlichen Web-`X-Airbnb-API-Key` (sonst `400 invalid_key`).
