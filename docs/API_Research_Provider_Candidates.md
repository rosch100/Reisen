# API-Recherche: Provider-Kandidaten & Sync-Lücken (August 2026)

Zweck: Consumer-Account-Sync („Meine Buchungen“) für Reisen bewerten — analog zu
[`API_Research_Opodo_Booking.md`](API_Research_Opodo_Booking.md).  
Partner-/Demand-APIs (Amadeus, Sabre, GYG Partner, Expedia Lodging Supply) bleiben **out of scope**.

**HAR-Quellen (lokal, gitignored):** `HAR/*.har`  
**Redigierte Fixtures:** [`fixtures/provider-research/`](fixtures/provider-research/) (keine Tokens/PII)

### Spec-Index (Umsetzung nach Freigabe)

| Spec | Inhalt |
|------|--------|
| [`dev/provider-activity-implementation-plan.md`](dev/provider-activity-implementation-plan.md) | **Ausführungsreihenfolge** Phase 0–2 (+ Phase 3+) |
| [`dev/booking-type-activity-impl-spec.md`](dev/booking-type-activity-impl-spec.md) | Gemeinsame Basis `BookingType.activity` |
| [`dev/airbnb-experiences-impl-spec.md`](dev/airbnb-experiences-impl-spec.md) | Airbnb Catalog + `activity_reservation_details` |
| [`dev/getyourguide-impl-spec.md`](dev/getyourguide-impl-spec.md) | Neuer Provider GYG |
| [`dev/check24-productkey-audit.md`](dev/check24-productkey-audit.md) | productKey-Inventory + Live-Audit-Checkliste |

Ausführungsdetails nur im Plan — nicht hier wiederholen.

---

## Architektur-Rahmen

| Modell | Beispiele | Passt zu Reisen? |
|--------|-----------|------------------|
| Consumer-Account-Sync | Check24 Kundenbereich, Booking My Trips, Airbnb Trips, **GetYourGuide customer-bookings** | **Ja** |
| Partner/Metasearch-API | Amadeus, Skyscanner Travel API, GYG Partner API, Expedia Lodging Supply | **Nein** |
| Gap-Deep-Links | Check24 Hotel/Flug-Suche | Teilweise (nur Suche, kein Sync) |

Neue Provider = [`TravelProvider`](../Sources/ReisenProviders/TravelProvider.swift) + `WKWebView`-Session, wie die **sechs** registrierten Anbieter (Check24, Opodo, Booking.com, Airbnb, GetYourGuide, Traveloka).

```mermaid
flowchart LR
  subgraph fit [Passend]
    GYG[GetYourGuide Account]
    Via[Viator Account]
    Exp[Expedia Trips]
  end
  subgraph unfit [Nicht passend]
    Ama[Amadeus GDS]
    Sky[Skyscanner API]
    GYGPartner[GYG Partner API]
  end
  UserKonto --> fit
  fit --> ReisenSync[TravelProvider Session Sync]
  unfit -.->|Partnervertrag Inventar| OutOfScope[OutOfScope]
```

---

## Priorisierte Kandidaten

### Prio 1 – Erlebnisse / Activities

| Provider | Sync-Pfad | Aufwand | Status Recherche |
|----------|-----------|---------|------------------|
| **Airbnb Experiences** | `TripListQuery` + `activity_reservation_details` | Niedrig | HAR ausgewertet; [Impl-Spec](dev/airbnb-experiences-impl-spec.md) |
| **GetYourGuide** | SSR `__INITIAL_STATE__` auf `/customer-bookings/` + `/booking/{hash}` | Niedrig–mittel | HAR ausgewertet; [Impl-Spec](dev/getyourguide-impl-spec.md) |
| **Traveloka** | Cookie-Session + `tripitinerary` fetch/single; Login E-Mail/OTP + Sign in with Apple | Mittel | HAR ausgewertet; [Impl-Spec](dev/traveloka-impl-spec.md) |
| Expedia / TripAdvisor | Account-Portal | Hoch | Auth/Captcha; siehe unten |
| Viator | Session/Login | Mittel–hoch | noch ohne HAR |
| TUI Musement | myTUI / Musement | Mittel | noch ohne HAR |

Domain-Basis: [`BookingType.activity`](dev/booking-type-activity-impl-spec.md). Reihenfolge: [Ausführungsplan](dev/provider-activity-implementation-plan.md).

### Prio 2 – Meta-OTA

| Provider | Hinweis | Status |
|----------|---------|--------|
| **Expedia Trips** (+ Hotels.com) | Consumer-Konto „Trips/Bookings“, nicht Lodging Supply GraphQL | [Bewertung](#expedia-trips--session-sync-bewertung) |
| HolidayCheck / weg.de / Ab-in-den-Urlaub | DE-Pauschal; HTML-lastig | nachrangig |

**Nicht als Sync:** Skyscanner, Kayak, Google Flights (Metasuche) — ggf. Gap-Deep-Links.

### Prio 3 – Transport (optional)

FlixBus/DB, Sixt — neuer Typ oder zuerst Check24-`productKey`-Whitelist (siehe [Check24](#check24--productkey-audit)).

---

## Teil A.1 – GetYourGuide HAR-Befunde

**HAR-SSOT** (Surfaces, Feldinventar, offene Punkte).  
**Mapping-SSOT:** [`getyourguide-impl-spec.md`](dev/getyourguide-impl-spec.md).

**Quelle:** `HAR/www.getyourguide.com_Archive [26-08-03 17-26-52].har` (532 Entries).  
**Fixtures:** `gyg_myBookings_redacted.json`, `gyg_bookingSummary_redacted.json`.

### Surfaces

| Rolle | URL / Endpoint | Inhalt |
|-------|----------------|--------|
| Katalog (SSR) | `GET …/de-de/customer-bookings/` | HTML mit `window.__INITIAL_STATE__.myBookings` |
| Detail (SSR) | `GET …/de-de/booking/{bookingHash}` | HTML mit `booking.bookingSummary` |
| Auth Token | `POST /auth/social/exchange` | Bearer + claims — **nicht** persistieren |
| Session Nachlauf | `POST travelers-api…/customer/management/v1/post-login` | nach Login |
| Profil | `GET travelers-api…/customers/{id}` | Stammdaten — Sync nicht nötig |
| GraphQL | `POST travelers-api…/graphql` | in HAR nur Wishlists — **nicht** Buchungsliste |
| QR/Voucher | `travelers-api…/barcode/qrcode?code=…` | in Detail referenziert |
| Tracking | Observer PageRequests | irrelevant |

**Kernbefund:** Liste + Details kommen als SSR-JSON in `__INITIAL_STATE__`, nicht über eine dedizierte Bookings-GraphQL-Query.

```mermaid
flowchart TD
  Login[WKWebView Login GYG]
  Login --> Token[Cookie Session]
  Token --> Catalog["GET /de-de/customer-bookings/"]
  Catalog --> State["Parse __INITIAL_STATE__.myBookings"]
  State --> Drafts[ProviderBookingDraft activity]
  Drafts --> Detail["GET /de-de/booking/hash"]
  Detail --> Summary["Parse booking.bookingSummary"]
  Summary --> Enrich[ProviderBookingEnrichment]
```

### Katalog-Felder (`myBookings`)

- Listen: `upcomingBookings`, `pastBookings` (HAR: Status `active` / `cancelled` / `done`)
- IDs: `bookingId`, `bookingHash`, `bookingReference`, `activityId`, `activityOptionId`
- Zeit: `startingTime.startTime` (ISO+Offset), `bookingFinishDate`
- Preis: `price.amount` / `price.currencyIsoCode`
- Titel/Ort: `bookedOption.activityTitle`, `activityOptionTitle`, `activityLocation.city/country`
- Typ: `activityType` (`dayTrip`, `multiDayTrip`, `guidedTour`, …)
- Teilnehmer: `activityParticipants[]`
- Storno: `bookingCancellationPolicy` (`type`, `message`, `expirationDate` / `policyExpirationDate`)

Catalog allein reicht für sinnvolle Drafts; Enrichment für Treffpunkt, Itinerary, feinere Policy.  
Feld→Domain-Mapping: [GYG Impl-Spec](dev/getyourguide-impl-spec.md).

### Offene Punkte (HAR)

- Dedizierte JSON-Bookings-API (Mobil) — für Web-SSR nicht nötig
- Pagination
- Login ohne Social
- Cloudflare/Bot-Schutz → WebView-Pfad

---

## Teil A.2 – Airbnb Experiences HAR-Befunde

**HAR-SSOT** (Surfaces, Katalog-Probleme, Code-vs-Soll).  
**Mapping-SSOT:** [`airbnb-experiences-impl-spec.md`](dev/airbnb-experiences-impl-spec.md).

**Quelle:** `HAR/www.airbnb.com.sg_Archive [26-08-03 17-47-22].har` (758 Entries).  
**Fixtures:** `airbnb_TripListQuery_experience_redacted.json`, `airbnb_activity_reservation_details_redacted.json`.

### Surfaces

| Rolle | Endpoint | HAR |
|-------|----------|-----|
| Katalog | `GET /api/v3/TripListQuery/…?operationName=TripListQuery` | Experience-Trip |
| Detail | `GET /api/v2/activity_reservation_details/EXPERIENCE_RESERVATION/{code}` | Rows-JSON |
| Nicht in dieser HAR | `TripDetailsQuery`, `/api/v2/scheduled_events/…` | im **bestehenden Code** für Stay-Enrichment |

### Katalog-Probleme (HAR bestätigt)

1. Titel = Trip-`displayName` (Ort), nicht Experience-Name → UX schlecht bis Enrichment
2. Code mappt Experiences → `.other` statt `.activity` ([`AirbnbTripsGraphQLParser`](../Sources/ReisenAirbnb/AirbnbTripsGraphQLParser.swift))
3. Gäste aus `travelerCapacity` vorhanden; Enrichment setzt Experiences bewusst auf `nil`

### Abgleich Code vs. Soll

| Aspekt | Code heute | Soll |
|--------|------------|------|
| Experience-Endpoint | `scheduled_events` + `TripDetailsQuery` | Primär **`activity_reservation_details`** |
| Titel | Trip `displayName` | Marquee-`title` |
| Typ | `.other` | `.activity` |
| Gäste | `nil` für Experiences | `travelerCapacity` / `guest_count` |

Row-`id`→Feld-Mapping: [Airbnb Impl-Spec § Neuer Parser](dev/airbnb-experiences-impl-spec.md#neuer-parser).

---

## Teil A.3 – Opodo HAR + Implement-Verdict

**Quelle:** `HAR/www.opodo.de_Archive [26-08-03 17-40-03].har` (~3784 Entries).  
**Fixture (Research):** `opodo_getTrips_upcoming_redacted.json`  
**Parser-Fixture (bestehend):** [`Tests/ReisenOpodoTests/Fixtures/getTrips_upcoming.json`](../Tests/ReisenOpodoTests/Fixtures/getTrips_upcoming.json)

### Kataloginhalt `getTrips(UPCOMING)`

| # | Typ | Inhalt |
|---|-----|--------|
| 1 | Flug | SIN→CGK, `transportTypes: [PLANE]`, Preis |
| 2–4 | Hotel | Unterkünfte, Board, Check-in/out |

`getTrips(PAST)` (Live 2026-08-28, Konto-Beleg): 5 Rows — 2× `PLANE`, 3× Hotel (davon RETAINED). **Keine** gebuchten Mietwagen, Transfers, Bahn, Activities. `vehicleBooking` ist kein Trip-Feld. `insuranceBookings` hängt als Ancillary am Trip, wird nicht abgefragt.

### Bereits im Code

Flug/Hotel über `getTrips` / `getTripByToken` / Support-Area Passengers+Baggage. HTML-Fallback nur bei **leerer** GraphQL-Liste (nicht bei GraphQL-Fehler). Upsell-Rows und Nicht-`PLANE`-Itineraries werden verworfen.

### Nicht syncen

| Signal | Bedeutung |
|--------|-----------|
| `GetVehicleRentalOffers*` / `VR_getTransferOffers*` | Upsell, keine Buchungen |
| FastTrack / Seat / Cabin-Bag Queries | Post-Booking-Verkauf |
| `insuranceBookings` | Ancillary — kein eigener Typ ohne Domain-Entscheidung |

### Epoch vs `departureDateISO8601`

- Section: Epoch als Pseudo-UTC-Wall-Clock + parallel `departureDateISO8601` mit Offset.
- Passt zu [`FlightTimeZoneAssigner`](../Sources/ReisenAppCore/FlightTimeZoneAssigner.swift) (`forWallClockInstant`).
- Blind auf ISO-Absolute umstellen **ohne** Offset-Pipeline → Zeiten kaputt.
- `arrivalDateISO8601` in HAR-Response fehlend → asymmetrisches Upgrade riskant.

### Implement-Verdict

**Katalog-Vertrag (Live 2026-08-28 + HAR):** nur Flug/Hotel; Upsell ignorieren; HTML nur wenn GraphQL leer.

- Neue Buchungstypen: **nein**
- `getTrips(UPCOMING)` kann leer sein, während PAST Flug/Hotel enthält — Katalog bleibt UPCOMING
- Optional später (separat spezifizieren): Departure-Offset aus ISO — nur mit Wall-Clock-Tests

---

## Teil A.4 – Traveloka HAR-Befunde

**HAR-SSOT** (Surfaces, Product-Types, Login TV+AP).  
**Mapping-SSOT:** [`traveloka-impl-spec.md`](dev/traveloka-impl-spec.md).

**Quelle:** `HAR/www.traveloka.com_Archive [26-08-25 17-53-21].har` (gitignored).  
**Fixtures:** `traveloka_itineraries_fetch_redacted.json`, `traveloka_itinerary_single_{hotel,experience,vehicle,flight,flight_fee}_redacted.json`, `traveloka_whoami_*.json`, `traveloka_transactions_number_redacted.json`.

### Surfaces

| Rolle | URL / Endpoint | Inhalt |
|-------|----------------|--------|
| Login | `GET …/en-en/user/signin?referrer=…/mybooking` | E-Mail/OTP + Sign in with Apple / Google / Facebook |
| Session-Probe | `POST /api/v2/user/whoami` | `loginMethod` ∈ {`TV`,`AP`,…}; `revoked` |
| Catalog | `POST /api/v2/tripitinerary/itineraries/v2/fetch` | `itineraryEntryList` (Gruppen ACTIVE_BOOKING) |
| Enrich | `POST /api/v2/tripitinerary/itineraries/v2/single` | `cardSummaryInfo` + `cardDetailInfo` |
| Optional Count | `POST …/transactions/number` | Badge-Zahlen — Sync nicht nötig |
| Detail-Deep-Link | `/en-en/item/details/{bookingId}?type={PRODUCT}&id={itineraryId}` | `externalUrl` |

**Pflicht-Header (Trip-Itinerary):** `x-domain: tripItinerary`, `x-client-interface: desktop`, `x-route-prefix: en-en`, `tv-language` / `tv-country` / `tv-currency`.

```mermaid
flowchart TD
  SignIn["signin E-Mail/OTP oder Apple"]
  WhoAmI["whoami loginMethod TV oder AP"]
  Catalog["itineraries/v2/fetch"]
  Drafts[ProviderBookingDraft]
  Enrich["itineraries/v2/single"]
  Sync[SyncProviderBookings]
  SignIn --> WhoAmI --> Catalog --> Drafts --> Enrich --> Sync
```

### Product-Type → Domain

| Traveloka | Domain |
|-----------|--------|
| `FLIGHT` | `.flight` |
| `HOTEL` (Villa/Apartment-Heuristik) | `.hotel` |
| `EXPERIENCE` | `.activity` |
| `VEHICLE_RENTAL` | `.carRental` |
| `TRAIN` / `TRAIN_GLOBAL` | `.train` (Typ-Mapping; **nicht** in Catalog-`itineraryTypes` — Live 2026-08-28 leere Liste) |
| Airport Transport, Ancillary, Insurance, unbekannt | `.other` |

### Feldinventar (Kurz)

- **Hotel:** dual Free+Fee-`cancellationPolicies`; Check-in/out Minuten; `hotelOffsetSeconds` aus `ianaTimezoneBegin`; Stay-Hints aus `importantNoticePolicies` / `propertyPolicy` (Live 2026-08-28); keine Pet-/Linen-Felder in diesem Konto
- **Experience:** `operatorInfo.name` → `operatorName`; All-Day → `isAllDay`; `travelersInfo` / `experiencePaxType` → `travellerType`; Policy-Strings für Free-Deadline
- **Vehicle:** `providerName` → `operatorName`; Pick-up/Drop-off Adressen; Free-Cancel-Local
- **Flight:** Live-E-Ticket `flightBookingInfo.bookingDetail` + `flightTicketInfo`; Non-Refundable ohne Deadline; Fee-Refund nur mit `refundFeeAmount` + `refundDeadlineLocal` (keine Free-Deadline erfinden)
- **Train:** Stub (`productName` + IANA-Offsets); Stations-Keys ohne Live-`single` nicht geraten

### Login (TV + AP)

1. E-Mail → MFA (`getotpinfo` / `sendotp` / `verifymfa`) → Cookies → `whoami` (`TV`)
2. Apple-Button im WKWebView → `appleid.apple.com` → `signinexternalaccount` (`AP`) — **kein** natives `ASAuthorization`
3. Autofill nur auf `*.traveloka.com`; IdP-Hosts nicht `sessionReady`

### Offene Punkte / Gap-Status (Stand Live 2026-08-28)

| Gap | Status |
|-----|--------|
| Fee-Refund-Flug Live-Shape | **Rest** — Konto ohne Fee-Flug; Fixture weiter synthetisch/schema-aligned |
| TRAIN Catalog+Stations | **Konto hat Vertical nicht** (UPCOMING 200 leer); Catalog-Types unverändert; Stations-Parser Rest |
| Product-Type-Heuristik Villa/Car | Unverändert; Unit-Tests für `VILLA`/`APARTMENT`/`CAR_RENTAL`; Live-Enums nicht gesehen |
| Pre-Travel Stay-Hints | **gefüllt** via Mapper + Traveloka-Enrichment bei leeren Hotel-`guestHints` (Catalog oft ohne Policies); Pets/Linen Rest („Petunjuk“ ≠ pet) |
| `PAST` Catalog-Status | API 400 — Code nutzt nur `UPCOMING` |

---

## Teil B – Bestehende Provider

### Check24 – productKey-Audit

SSOT (Keys, Hypothesen, Live-Checkliste): [`check24-productkey-audit.md`](dev/check24-productkey-audit.md).  
Kurz: Code-Whitelist bekannt; vollständige Live-API-Keys **fehlen** (keine Check24-HAR).

### Booking.com

**Heute:** GraphQL-Reservierungen `FLIGHT` + `ACCOMMODATION`.  
**Offen:** Attractions/Taxi/Car in My Trips — nur mit eigener HAR prüfen.  
`supportedExperiences` / Connectors sind **UI-Flags**, keine Activity-Buchungen.

### Airbnb / Opodo (nach HAR)

Siehe A.2 bzw. A.3 — keine zusätzlichen Teil-B-Befunde.

---

## Expedia Trips – Session-Sync-Bewertung

### Was nicht passt

- **Expedia Group Lodging Supply GraphQL** (`api.expediagroup.com/supply/lodging/graphql`): B2B Properties/Partner — falscher Scope.

### Was passen würde

- Consumer-UI **Trips / Bookings** nach Login (`expedia.de` / `.com`, Hotels.com).
- Pfad analog Booking/Airbnb: WKWebView-Login → authenticated Trip-Liste + Detail.

### Machbarkeit (ohne eigene Expedia-HAR)

| Kriterium | Einschätzung |
|-----------|--------------|
| Scope-Fit | Hoch |
| Technische Nähe | Mittel–hoch |
| Öffentliche Consumer-JSON-API | Nein |
| Blocker | Keine HAR — Endpunkte unbekannt |
| Risiko | Bot-Schutz, Locale, Hotels.com-vs-Expedia-Session |

**Verdict:** Prio 2 nach Activity-Arbeit. Nächster Schritt: Expedia.de-HAR (Hotel + optional Flug), dann Impl-Spec. Bis dahin kein Produktivcode.

---

## Plan-Conformity / offene Blocker

| Plan-Todo | Recherche-Status | Rest |
|-----------|------------------|------|
| Spec-Doc GYG/Airbnb/Opodo | erledigt | — |
| Airbnb/GYG Impl-Specs + Activity-Basis + Ausführungsplan | erledigt | Phase 0–2 Produktivcode umgesetzt |
| Opodo Verdict „kein Muss“ | erledigt | optional TZ später |
| Expedia Bewertung | erledigt | Live-HAR fehlt |
| Check24 „alle productKeys erfassen“ | **teilweise** | Live-HAR fehlt; Code-known Keys + Fixture dokumentiert |
| Redigierte Fixtures GYG/Airbnb/(Opodo) | erledigt | Check24-Keys-Fixture (Code-SSOT); Live-Keys fehlen |
| Activity Produktivcode (Airbnb + GYG) | erledigt | Unit-Tests grün; Live-Sync manuell prüfen |

---

## Datenschutz

- Roh-HARs: JWTs/Kundendaten — **gitignored** (`HAR/`, `*.har`).
- Fixtures unter `docs/fixtures/provider-research/` sind redigiert.
- Keine Tokens/PII in Specs oder Commits.
