# Implementation-Spec: GetYourGuide Consumer-Sync

Status: **Implementiert** (SPM-Target + Unit-Tests gegen redigierte Fixtures).  
Phase: [`provider-activity-implementation-plan.md`](provider-activity-implementation-plan.md) Phase 2.  
HAR-Befunde: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § A.1.  
Fixtures: [`../fixtures/provider-research/gyg_*.json`](../fixtures/provider-research/).

## Ziel

Neuer Provider `ReisenGetYourGuide` / `ProviderID.getYourGuide`: persönliche Activity-Buchungen über Login + authenticated HTML (`__INITIAL_STATE__`).

## Surfaces (Implementierungs-URLs)

HAR-Inventar inkl. Auth/GraphQL/QR: Research A.1. Primärpfad:

| Schritt | URL | Parse |
|---------|-----|-------|
| Login-Start / Catalog | `https://www.getyourguide.com/de-de/customer-bookings/` | `window.__INITIAL_STATE__.myBookings` |
| Enrich | `https://www.getyourguide.com/de-de/booking/{bookingHash}` | `booking.bookingSummary` |

## Target / Package

1. SPM-Target `ReisenGetYourGuide` (Dependencies: Domain, Providers)
2. `ProviderID.getYourGuide` + Logo/Registry/iOS-Sync-Liste
3. Login-URL = Catalog-URL; Keychain-Host `getyourguide.com`

## Catalog-Mapping (`myBookings`)

Listen: `upcomingBookings` (Primärfilter, analog „ab heute“), optional `pastBookings` später.

| GYG | Reisen |
|-----|--------|
| Activity-Buchung | `BookingType.activity` ([Basis-Spec](booking-type-activity-impl-spec.md)) |
| `bookingReference` oder `bookingHash` | `confirmationCode` |
| `/de-de/booking/{bookingHash}` | `externalUrl` |
| `bookedOption.activityTitle` | `title` |
| `startingTime.startTime` | `startAt` |
| `bookingFinishDate` | `endAt` |
| `bookedOption.activityLocation.city.name` | `locationTo` |
| `price.amount` / `currencyIsoCode` | Rate/Preis |
| `status` `active`/`cancelled`/`done` | `confirmed` / `cancelled` / ggf. skip past |
| `bookingCancellationPolicy.expirationDate` | `cancellationDeadline` (freeCancellation → isFree) |

Parser: robuster Extract von `__INITIAL_STATE__` (Brace-Scan, kein naives Regex bis Dateiende).

## Enrichment (`booking.bookingSummary`)

| Quelle | Mapping |
|--------|---------|
| `activity.meetingPoint` | `locationToAddress` / Treffpunkt-Text |
| `activity.itinerary` | optional Notes |
| `booking.bookingCancellationPolicy` | Deadlines verfeinern |
| `activityParticipants` | Travellers (ohne PII in Logs) |
| QR `travelers-api…/barcode/qrcode` | optional `externalUrl`/Voucher — nicht Pflicht |

## Auth-Hinweise

- Social/OIDC (`POST /auth/social/exchange` → Bearer) — **nicht** persistieren/loggen.
- Primärpfad: Cookie-Session der WebView für die beiden HTML-GETs (`fetchAuthenticatedText` / Cookie-`URLSession` wie Airbnb/Booking).
- Login-Start-URL = Catalog-URL (erzwingt Auth-Redirect).
- API-Header aus HAR (nur falls SSR ohne Cookies scheitert): `Authorization: Bearer …`, `x-gyg-app-type: Web`, `x-gyg-partner-hash`, `apollographql-client-name` — Werte nicht hardcoden aus HAR.

## Tests

- `gyg_myBookings_redacted.json` → Drafts
- `gyg_bookingSummary_redacted.json` → Enrichment
- Keine echten Tokens/Hashes in Assertions (Fixtures sind redigiert)

## Offene Punkte (HAR)

Siehe Research A.1 (Pagination, Login ohne Social, Cloudflare).

## Nicht in Scope

- GetYourGuide Partner API
- Wishlists / Recommendations
