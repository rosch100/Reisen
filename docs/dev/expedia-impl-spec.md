# Implementation-Spec: Expedia.de Consumer-Sync

Status: **Umsetzung** (SPM-Target `ReisenExpedia`).
HAR: lokal `HAR/www.expedia.de_Archive [26-09-09 *.har]` (gitignored).
Fixtures: [`../fixtures/provider-research/expedia_*.json`](../fixtures/provider-research/) (+ HTML).

## Ziel

Neuer Provider `ReisenExpedia` / `ProviderID.expedia`: persönliche Buchungen über Cookie-Session + Persisted GraphQL (`www.expedia.de/graphql`).

## Surfaces

| Schritt | URL / API | Parse |
|---------|-----------|-------|
| Login | `https://www.expedia.de/login` | WKWebView; Arkose/OTP nicht nachbauen |
| Session-Probe | Cookie `EG_SESSIONTOKEN` + `GET /trips` ohne Login-Redirect (`isLoginHTML`); Hub: `shouldProbeExpedia` | GraphQL-Context `authState=AUTHENTICATED`, `duaid` aus Cookie `DUAID` (fehlt → Fehler) |
| Catalog | `GET /trips` → `egti-*` Links; je Trip `SharedUIWeb_TripItemsQuery` (BOOKED) | Nur Cards mit `__typename=TripsUIBookedItemCard`; Hotel: Kalendertag + Check-in/out-Minuten; unparsebare Zeiten → skip + Log |
| Enrich | `TripItemQuery`; Hotel: `RoomDetailsQuery` + `BookingServicingManageQuery` | Bestätigungsnr., Preis, Cancel-URL (Hotel best-effort), Fristen |
| Open | Card `cardAction.resource` | `/trips/{egti}/details/{tripItemId}` |
| Cancel Hotel | BookingServicing voluntary cancel review | `.distinctURL` |
| Cancel Car | `…/manage-booking` + Assist (Dialog → Ja, jetzt stornieren) | `.inPageOnOpen` |

## Host- / URL-SSOT

| Konzept | Ort |
|---------|-----|
| `origin`, `portalHost`, Trips-URL, Session-Cookies | `ExpediaSessionProbe` (`ReisenProviders`) |
| `isPortalHost` / `isManageBookingURL` | `ExpediaSessionProbe` (Assist delegiert) |
| Login/GraphQL-URLs | `ExpediaAPI` (leitet Origin/Host vom Probe) |
| Detail- / Manage-Booking-URL bauen | `ExpediaExternalURL` |

## Persisted GraphQL (expedia.de)

SSOT im Code: `ExpediaGraphQL.PersistedOperation` (`name` + `sha256Hash` + `pageID`).

| operationName | sha256Hash |
|---------------|------------|
| `SharedUIWeb_TripItemsQuery` | `c53c91d271e7644df446ce719e13209914e854d8ecfcd438c4849a65dcc03985` |
| `TripItemQuery` | `5f38e6230f36e0b3b3e2cd3fc58074ea17e7af32b03a2761adbb14a400e54df4` |
| `RoomDetailsQuery` | `bc7cb5bfe81736ea198026138bdcaf65ebede6691f01b3d75540d7cc1df079ac` |
| `BookingServicingManageQuery` | `290ca1ec53212887b09bba72925619d90bd59f4e3f64ad3c1c6d6d480a98770f` |

Hotel-Servicing-`tripId` = UUID-Segment aus Base64-`tripItemId` (nicht `egti-*`).
`PersistedQueryNotFound` / `persistedQuery*` → harter Fehler + Log (`hash_rejected`).
GraphQL-`errors` (auch neben `data`) → Fehler, kein stilles Weiterlaufen mit Partial-Data.

Hotel-Side-Paths:

| Pfad | Hash / GraphQL-`errors` | Sonst |
|------|-------------------------|--------|
| RoomDetails | hart (inkl. `CancellationError`) | soft (Log `side_path_failed`; Deadlines/Category best-effort) |
| BookingServicing | hart (inkl. `CancellationError`) | Cancel-URL / undecodierbare Lodging-`tripId` soft (Log); TripItem-Enrich bleibt |

Primary Catalog/Enrich: Start + Erfolg/`failed`/`cancelled` via `DiagnosticLogger` (nicht nur SyncLog).

## LOB → BookingType

| Prefix | Type |
|--------|------|
| `eg:property:v2:` | `.hotel` |
| `eg:car:v2:` | `.carRental` |
| `eg:flight:v2:` | `.flight` |
| `eg:activity:v2:` | `.activity` |
| unbekannt | skip + Log |

Cancel-URL im Katalog (`ExpediaProductType.usesManageBookingAsCancellationURL`): Car → Manage-Booking; Flight/Activity → `nil` bis Cancel-Capture; Hotel → `nil` (kommt aus Enrich/Servicing).

## Zeiten / Fristen

| LOB | Regel |
|-----|--------|
| Hotel (Catalog/Schedule) | Kalendertag (`HotelStayDate`) + `hotelCheckIn/OutMinutes` — **keine** erfundene Property-TZ |
| Car/Flight/Activity | Wandzeiten in `Europe/Berlin` (Portal-Locale expedia.de / `de_DE`) |
| Free-Cancel-Deadlines | „Ortszeit der Unterkunft“ → **skip** (kein Berlin-Absolut); sonst Wandzeit in `Europe/Berlin` (Portal-Locale; pure Parser, kein Extra-Log) |

## Enrichment-Gate

`ExpediaDraftEnrichmentNeeds.shouldEnrich`: nur wenn `confirmationCode == nil`.

- Katalog setzt **keine** Reiseplan-Nummer als `confirmationCode` (Identity: `BookingIdentityKey`).
- Enrich übernimmt nur echte Bestätigungsnr. (`Bestätigungsnr.` / Confirmation-Patterns).
- Fehlende Hotel-Cancel-URL, fehlender Preis oder leere Ortszeit-Deadlines lösen **keinen** Dauer-Re-Enrich aus.
- Hotel-Servicing soft-fail wie oben; Needs danach nicht erneut nur wegen fehlender Cancel-URL.

## Cancel-Assist (Car)

`shouldRun`: `provider == .expedia` **und** URL `/manage-booking` **und** `bookingType == .carRental`.
JS nur bei Car-Marker (`TripsCancelCarAction` / `cancelCar` / `TIM.CAR.NAV.CancelReservation`); DE-Labels aus HAR.
`PortalCancelCompletionDetector` ohne Expedia-Zweig (v1).

## Gap

Hotel (`Hotel-Search`), Car (`carsearch/details`, nur mit konkreten Zeiten). Kein Flight/Activity-Gap in v1.

## Tests / Fixtures

- `Tests/ReisenExpediaTests` (Parser, Needs, GraphQL-Errors, Soft-Cancel-Parser, `confirmationCode` apply)
- `Tests/ReisenProvidersTests` (Session-Probe, Car-Cancel-Assist)
- MacUI-Smoke: Expedia-Provider-Zeile
- Fixtures unter `docs/fixtures/provider-research/expedia_*` (redigiert/synthetisch)

## Nicht in Scope

Hotels.com, Lodging Supply, `cancelCar`-Mutation außerhalb WebView, Flight/Activity-Cancel-Assist, spekulativer CompletionDetector.
