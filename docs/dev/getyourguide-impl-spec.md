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
| Login-Start | `https://www.getyourguide.com/login?next=/de-de/customer-bookings/` | passwordless E-Mail-OTP in der WebView |
| Catalog | `https://www.getyourguide.com/en-us/customer-bookings/` | `window.__INITIAL_STATE__.myBookings` |
| Enrich | `https://www.getyourguide.com/en-us/booking/{bookingHash}` | `booking.bookingSummary` |

## Target / Package

1. SPM-Target `ReisenGetYourGuide` (Dependencies: Domain, Providers)
2. `ProviderID.getYourGuide` + Logo/Registry/iOS-Sync-Liste
3. Login-URL = `/login?next=/de-de/customer-bookings/` (passwordless OTP); Sync-Catalog EN; Keychain-Host `getyourguide.com`

## Catalog-Mapping (`myBookings`)

Listen: `upcomingBookings` **und** `pastBookings` (gleiche Mapper, Dedup per `bookingHash` erst nach erfolgreichem Mapping). GYG schiebt beendete Termine nach `past` (auch Status `active`). `done`/`ended` skip; ohne `bookingHash` oder `bookingFinishDate` skip. Keine Pagination-Felder (HAR 2026-08-28).

| GYG | Reisen |
|-----|--------|
| Activity-Buchung | `BookingType.activity` ([Basis-Spec](booking-type-activity-impl-spec.md)) |
| `bookingReference` oder `bookingHash` | `confirmationCode` |
| `/en-us/booking/{bookingHash}` | `externalUrl` |
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
| `activity.meetingPoint` | `locationToAddress` / Treffpunkt-Text + GuestHint „Treffpunkt“ |
| `activity.restrictions` / `inclusions` / `isMobileVoucherAccepted` | `BookingGuestHint` (Kategorie preTravelImportant) |
| `activity.itinerary` (wichtige Items) | GuestHints „Ablauf“ |
| `booking.bookingCancellationPolicy` | Deadlines verfeinern |
| `activityParticipants` | Travellers (ohne PII in Logs) |
| QR `travelers-api…/barcode/qrcode` | optional `externalUrl`/Voucher — nicht Pflicht |

## Auth-Hinweise

- E-Mail-Login ist **passwordless OTP** in der WebView (`POST /auth/passwordless/otp/send` → Nutzer-Code → `POST /auth/passwordless/otp/exchange`). `signupMethod`: `pre_payment_otp`; Claim `gyg/auth_provider`: `email`. Kein natives OTP-API.
- Social/OIDC (`POST /auth/social/exchange` → Bearer) bleibt optional — in der E-Mail-HAR nicht gefeuert.
- Access-Token, OTP, E-Mail und Claims **nicht** persistieren/loggen. Session über Cookies `tfe_access_token` / `tfe_authenticated_session` (HttpOnly).
- Primärpfad: Cookie-Session der WebView für die beiden HTML-GETs (`fetchAuthenticatedHTML` / Cookie-`URLSession` wie Check24/Opodo). Login-HTML (Redirect auf `/login`, passwordless-Marker, oder `__INITIAL_STATE__` ohne Objekt-Keys `myBookings`/`bookingSummary`) → `sessionNotEstablished`. Asset-Substrings, JSON-`null` und String-Werte zählen nicht; nur JSON-Objekte. Leeres `myBookings`-Objekt zählt als Session (leerer Katalog), nicht als Login. HTTP 401/403 oder 200 mit Cloudflare-Challenge-Body (auch unter `/login`) → `cloudflareChallenge` (nicht „bitte anmelden“).
- Login-Start-URL = `/login?next=/de-de/customer-bookings/` (OTP-Autofill + E-Mail-Fill ab erster Navigation; nach Login `next=` → Kundenbuchungen).
- API-Header aus HAR (nur falls SSR ohne Cookies scheitert): `Authorization: Bearer …`, `x-gyg-app-type: Web`, `x-gyg-partner-hash`, `apollographql-client-name` — Werte nicht hardcoden aus HAR.

## Tests

- `gyg_myBookings_redacted.json` → Drafts
- `gyg_myBookings_ssr_lists_redacted.json` → leeres Upcoming, Past gemappt, keine Pagination-Keys
- `gyg_bookingSummary_redacted.json` → Enrichment
- Keine echten Tokens/Hashes in Assertions (Fixtures sind redigiert)

## Offene Punkte (HAR)

Siehe Research A.1. Login ohne Social, Pagination und Cloudflare sind geschlossen: passwordless OTP in der WebView, ein HTML-GET für den Katalog, Cloudflare nur CDN ohne Challenge.

## Nicht in Scope

- GetYourGuide Partner API
- Wishlists / Recommendations
