# Implementation-Spec: Traveloka Consumer-Sync

Status: **Implementiert** (SPM-Target `ReisenTraveloka` + Unit-Tests gegen redigierte Fixtures).  
Plan: Traveloka Provider Sync.  
HAR: lokal `HAR/www.traveloka.com_Archive [26-08-25 17-53-21].har` (gitignored).  
Fixtures: [`../fixtures/provider-research/traveloka_*.json`](../fixtures/provider-research/) (+ Refund-HTML).

## Ziel

Neuer Provider `ReisenTraveloka` / `ProviderID.traveloka`: persönliche Buchungen (Hotel, Flight, Experience/Activity, Vehicle Rental, …) über Cookie-Session + Trip-Itinerary-APIs.

## Surfaces

| Schritt | URL / API | Parse |
|---------|-----------|-------|
| Login-Start | `https://www.traveloka.com/en-en/user/signin?referrer=/en-en/user/mybooking` | Interaktives WKWebView (E-Mail/OTP **oder** Sign in with Apple) |
| Session-Probe | `POST /api/v2/user/whoami` | `data.loginMethod` ∈ {`TV`,`AP`,…}; kein `revoked` |
| Catalog | `POST /api/v2/tripitinerary/itineraries/v2/fetch` (+ optional `transactions/number`) | Itinerary-Entries / Gruppen `ACTIVE_BOOKING`; Phasen `UPCOMING` + `PAST` |
| Enrich | `POST /api/v2/tripitinerary/itineraries/v2/single` | `cardSummaryInfo` + `cardDetailInfo` |
| Refund (wenn Detail ohne Deadlines) | `GET /en-en/refund/presubmission/{PRODUCT}/{bookingId}/{itineraryId}` | `__NEXT_DATA__` Deadline-Locals |
| Detail-Deep-Link | `/en-en/item/details/{bookingId}?type={PRODUCT}&id={itineraryId}` | `externalUrl` |

## API-Header (SSOT aus HAR)

Pflicht für Trip-Itinerary-POSTs:

- `x-domain: tripItinerary`
- `x-client-interface: desktop`
- `x-route-prefix: en-en`
- `content-type: application/json`
- `tv-language` / `tv-country` / `tv-currency` (z. B. `en_EN` / `EN` / `EUR`)
- Session-Cookies (`tvs`, `tvl`, `tvo`, …) via `fetchAuthenticatedText`

Aus laufender WebView-Session (keine Fixture-Hardcodings):

- Cookie `sen_t` → Body `sentinel.token`
- Cookie `clientSessionId` → Header `tv-clientsessionid`
- Device-ID (Web Storage / optional Cookie) → Header `x-did` (Base64 der ULID)

### `itineraries/v2/single` Request (HAR)

```json
{
  "fields": [],
  "data": {
    "bookingId": "…",
    "itineraryId": "…",
    "featureConfig": { "featureTypes": ["BOOKING_NAVIGATION"] }
  },
  "clientInterface": "desktop",
  "sentinel": { "token": "…", "signals": [] }
}
```

## Product-Type → Domain

| Traveloka `itineraryType` | `BookingType` |
|---------------------------|---------------|
| `FLIGHT` | `.flight` |
| `HOTEL` (Villa/Apartment analog) | `.hotel` |
| `EXPERIENCE` | `.activity` |
| `VEHICLE_RENTAL`, Airport Transport, Train, Flight Facilities, Insurance, unbekannt | `.other` |

Status-SSOT: Tag/Text `Voucher issued` / `E-ticket issued` / `userTripStatus: ETICKET_PUBLISHED` → `.confirmed`; cancelled/refunded → `.cancelled`; sonst `.unknown`.

## Feld-Mapping (Kurz)

Siehe Plan-Tabellen. Domain-Erweiterungen: `operatorName`, `isAllDay`.

- Experience: `operatorInfo.name` → `operatorName`; `timeSlotId == all_day_pass` / „All Day“ → `isAllDay`
- Hotel: dual Free+Fee-`CancellationDeadline`; `hotelCheckInMinutes` / `hotelCheckOutMinutes`; `hotelOffsetSeconds` aus `ianaTimezoneBegin`
- Flight: keine Free-Deadline erfinden; Fee/Non-Refundable nur aus echten Feldern
- Vehicle: `operatorName` aus PROVIDED BY / Partner

## Login

1. E-Mail/Passwort → ggf. MFA (`getotpinfo` / `sendotp` / `verifymfa`) → `signin` 200 → Cookies
2. Sign in with Apple: UI-Button `AP` → `appleid.apple.com` im selben WKWebView (Popup→`createWebViewWith`) → Browser ruft `signinexternalaccount` — **nicht** nachbauen
3. Kein natives `ASAuthorizationAppleIDProvider` in v1
4. Autofill nur auf `*.traveloka.com`; IdP-Hosts (`apple.com` / `appleid.`) nicht `sessionReady`

## Gap-Deep-Links

`TravelokaDeepLinkBuilder`: `flight`, `hotel`, `activities` (Things to Do). Kein Train.

## Tests

- `traveloka_itinerary_single_*_redacted.json` → Enrichment pro Product-Type (inkl. Fee-Flug)
- `traveloka_itineraries_fetch_redacted.json` → Catalog-Drafts (Experience + Hotel + Vehicle + Flight)
- `traveloka_whoami_redacted.json` / `traveloka_whoami_apple_redacted.json` → Session-Probe (`TV` / `AP`)
- `traveloka_whoami_anonymous_redacted.json` → nicht eingeloggt ohne `loginMethod`
- Keine echten Tokens/PII in Assertions

## Nicht in Scope

- Partner-API, Payment Method, Redeem-Fließtext, Special Requests, Train-Desktop-Sync
