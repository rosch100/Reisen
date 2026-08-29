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
| Catalog | `POST /api/v2/tripitinerary/itineraries/v2/fetch` (+ optional `transactions/number`) | Itinerary-Entries / Gruppen `ACTIVE_BOOKING`; Phase **`UPCOMING` only** (Live 2026-08-28: `PAST` → HTTP 400 Illegal argument) |
| Enrich | `POST /api/v2/tripitinerary/itineraries/v2/single` | `cardSummaryInfo` + `cardDetailInfo` |
| Refund (wenn Detail ohne **Fee**-Deadline) | `GET /en-en/refund/presubmission/{PRODUCT}/{bookingId}/{itineraryId}` | `__NEXT_DATA__` Deadline-Locals; **mergen** (Itinerary-Free behalten, Fee ergänzen) |
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
| `VEHICLE_RENTAL` | `.carRental` |
| `TRAIN` / `TRAIN_GLOBAL` | `.train` |
| Airport Transport, Flight Facilities, Insurance, unbekannt | `.other` |

Status-SSOT: Tag/Text `Voucher issued` / `E-ticket issued` / `userTripStatus: ETICKET_PUBLISHED` → `.confirmed`; cancelled/refunded → `.cancelled`; sonst `.unknown`.

## Feld-Mapping (Kurz)

Siehe Plan-Tabellen. Domain-Erweiterungen: `operatorName`, `isAllDay`.

- **Preis (alle Produkttypen):** `paymentInfo.expectedAmount` → `rateDetails.totalPriceAmount` / `totalPriceCurrency` via `TravelokaJSON.bookingMoney` / `money` (`amount` + `numOfDecimalPoint`, z. B. `362`+`2` → `3.62`). Overlay in `facts(from:)` nach produkt-spezifischen Rate-Feldern (`BookingRateDetails.merging`). Bei `isTotalPriceHidden` / `totalPriceHidden` == true → kein Preis (`nil`, UI „k. A.“). **Nicht** Storno-`FULL_CHARGE`-Fee als Buchungspreis.
- Experience: `operatorInfo.name` → `operatorName`; `timeSlotId == all_day_pass` / „All Day“ → `isAllDay`
- Hotel: Live-API `hotelDetail.voucherInfo` + `localeAwareInfos` (kein `hotelSummary`); Ort `bookingInfo.hotelBookingInfo.hotelGeoDisplayName`; Free+Fee-Fristen primär aus `cancellationPolicyInfos` (`FREE_CANCELLATION` / `FULL_CHARGE`, Betrag = `amount` / `10^numOfDecimalPoint`); Fallback Policy-String; Check-in/out aus Voucher-Zeiten; **Stay-Hints** aus `importantNoticeDisplay.importantNoticePolicies`, `propertyPolicy` (Hausregeln), optional `checkInInstruction` nur bei `BookingGuestHintPrepKeywords` — **nicht** `specialRequests`
- Flight: Live-E-Ticket liest `bookingInfo.flightBookingInfo.bookingDetail` (Segmente `segments`, sonst `routes` / `flightRouteGroups`; Airports `sourceAirport`/`destinationAirport` oder Search-Shape `departureCity`/`arrivalCityCode`) plus `flightTicketInfo.eTicketDetailMap` / `eTicketButtonInfo`. Kein `flightSummary`. Keine Free-Deadline erfinden; Fee nur mit echter Deadline (`refundFeeAmount` + `refundDeadlineLocal` bzw. Refund-HTML)
- Train: `TRAIN`/`TRAIN_GLOBAL` → `.train`; Titel `productName`; `ianaTimezoneBegin`/`ianaTimezoneEnd` → Flight-Offsets (Anzeige-Ortszeit). Stations-/Sitz-Parser folgt mit HAR. **Nicht** in `catalogItineraryTypes` (Live 2026-08-28 Research-fetch: UPCOMING 200 + leere Liste, Konto-Beleg)
- Vehicle: `supplierName`, `pickupLocation`/`pickupAddress` (nicht `providerName`/`pickUpAddress`); Titel `vehicleName` + `routeName`; Transmission `withoutDriverDetailInfo.product.transmissionTypeLabel`; Free-Frist 24h vor Pickup (EN „24 hours before“ / ID „24 jam sebelum“); Zeitzone oft Offset `+07:00` statt IANA

## Login

1. E-Mail/Passwort → ggf. MFA (`getotpinfo` / `sendotp` / `verifymfa`) → `signin` 200 → Cookies
2. Sign in with Apple: UI-Button `AP` → `appleid.apple.com` im selben WKWebView (Popup→`createWebViewWith`) → Browser ruft `signinexternalaccount` — **nicht** nachbauen
3. Kein natives `ASAuthorizationAppleIDProvider` in v1
4. Autofill nur auf `*.traveloka.com`; IdP-Hosts (`apple.com` / `appleid.`) nicht `sessionReady`

## Gap-Deep-Links

`TravelokaDeepLinkBuilder`: `flight`, `hotel`, `activities` (Things to Do). Kein Train.

## Tests

- `traveloka_itinerary_single_*_redacted.json` → Enrichment pro Product-Type (inkl. Fee-Flug + Cancelled; alle mit `paymentInfo.expectedAmount`)
- `traveloka_itineraries_fetch_redacted.json` → Catalog-Drafts (Experience + Hotel + Vehicle + Flight; Preise aus `expectedAmount`)
- `traveloka_whoami_redacted.json` / `traveloka_whoami_apple_redacted.json` → Session-Probe (`TV` / `AP`)
- `traveloka_whoami_anonymous_redacted.json` → nicht eingeloggt ohne `loginMethod`
- Keine echten Tokens/PII in Assertions

## Nicht in Scope

- Partner-API, Payment Method, Redeem-Fließtext, Special Requests
- TRAIN-Stations-/Sitz-Parser (kein TRAIN-Detail-HAR im Repo; Typ-Mapping existiert; Catalog fragt TRAIN nicht an)
- Pet-Keywords in `BookingGuestHintPrepKeywords` (Live 2026-08-28: kein Pet-Policy-Feld; `/pet/i` trifft ID „Petunjuk“ = False-Positive)

## Live-Research 2026-08-28 (Konto-Beleg)

| Frage | Ergebnis |
|-------|----------|
| `fetch` + `TRAIN`/`TRAIN_GLOBAL` UPCOMING | HTTP 200, `SUCCESS`, **leere** Bahn-Liste |
| `fetch` PAST (mit/ohne TRAIN) | HTTP **400** Illegal argument |
| Sichtbare `itineraryType` | `HOTEL`, `EXPERIENCE`, `VEHICLE_RENTAL` (kein `VILLA`/`APARTMENT`-Enum in diesem Konto; Heuristik unverändert) |
| Fee-Refund-Flug | **nicht** in Katalog → Fixture weiter synthetisch |
| Stay-Regeln Hotel | Policies in **`single`** (`importantNoticePolicies`, `propertyPolicy`, …); Catalog-Karten oft ohne — Traveloka enrich’t Hotels mit leeren `guestHints`. Haustiere/Bettwäsche **nicht** belegt |

### Konformitätsprotokoll

- Facts → `DraftAssembler` (`guestHints` über `ProviderBookingFacts`); kein zweites Draft-Init
- no-fallbacks: fehlende Stay-Felder → leeres Array; keine geratenen TRAIN-Station-Keys; TRAIN nicht in Whitelist ohne Entries; fehlender/versteckter Preis → `nil` (kein Storno-Fee als Total)
- SSOT: Typ-Mapping `TravelokaProductType`; Prep-Keywords Domain; Catalog-Types unverändert; Geldwerte `TravelokaJSON.money` / `bookingMoney` / `moneyAmount`; `BookingRateDetails` im Entry-Parser
- Preis: `paymentInfo.expectedAmount` in Catalog und Single (gleicher Entry-Parser); wie GYG/Booking/Opodo/Check24/Airbnb/BM auf `BookingRateDetails.totalPriceAmount`
- Traveloka `needsDraftEnrichment`: Hotel mit leeren `guestHints` → `single` (Catalog-Karten oft ohne Policies; Sync überschreibt Hints aus dem Draft); **nicht** wegen fehlendem Preis (Catalog liefert denselben Payment-Pfad)
- Doc-Drift A.4 TRAIN → `.train` korrigiert
