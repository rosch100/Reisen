# Booking.com My-Trips GraphQL-Audit

Status: **Live 2026-08-28** (eingeloggtes Konto, Cursor-Browser, `GetTripsQuery` + `SingleTimelineQuery` V1).

Siehe Überblick: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § Booking.com.

Rohpayload nicht committed (PII). Auswertung: Typen, `verticalType`, Feldschlüssel, Query-Shape.

## Live-Request

Eingeloggt auf `https://secure.booking.com/mytrips.de.html`. Trip-XP-MFE lädt GraphQL im Browser-Kontext (Cookies + AWS-WAF-Challenge).

| Request | Rolle |
|---------|--------|
| `POST https://secure.booking.com/dml/graphql?lang=de` | Katalog + Timeline (V1). Ohne `?lang=` ebenfalls 200. |
| Capla-JS `33a76ba0.*.chunk.js` / `3ef7fa82.*.chunk.js` | `GetTripsQuery` / `SingleTimelineQuery` (+ V2-Document) |
| `https://d8c14d4960ca.edge.sdk.awswaf.com/…/challenge.js` | WAF; Token sitzt in Cookies, nicht in GraphQL-Headern |

In-Page-`fetch` (wie `BookingComTravelProvider.postGraphQL`) ist der funktionierende WAF-Pfad. CSRF + `apollographql-client-*` wie bisher; Client-Version kam in dieser Session aus Wishlist-MFE-Fallback (`b-wishlist-wishlist-mfe` + Suffix).

## Konto vs. Schema

`CURRENT`+`UPCOMING`: **0** Trips (keine offenen Reisen in diesem Konto).  
`PAST`: **36** Trips, **51** `ReservationTripItem` (4 Seiten à 10).

Sync bleibt bewusst bei `CURRENT`+`UPCOMING` (PAST bläht den Katalog auf). Taxi in diesem Konto lag nur in PAST — Mapping gilt für künftige Upcoming-Taxis.

## Reservation-`__typename` / `verticalType`

### In diesem Konto (Live-Timeline)

| `__typename` | `verticalType` | n | Domain |
|--------------|----------------|---|--------|
| `AccommodationReservation` | `ACCOMMODATION` | 47 | `.hotel` |
| `FlightReservation` | `FLIGHT` | 2 | `.flight` |
| `PrebookTaxiReservation` | `PREBOOK_TAXI` | 2 | `.other` |

`tripItems.__typename` in den Antworten: nur `ReservationTripItem`.

### Im MFE-Schema, **0 in diesem Konto** (nicht „API existiert nicht“)

| `__typename` | vermutetes `verticalType` | Domain-Mapping im Code | Beleg |
|--------------|---------------------------|------------------------|-------|
| `AttractionReservation` | `ATTRACTION` | `.activity` | MFE-Fragment; 0 Timeline-Treffer |
| `CarReservation` | `CAR` | `.carRental` | MFE-Fragment; 0 Timeline-Treffer |
| `RequestToBookReservation` | `REQUEST_TO_BOOK` | ungemappt → `.other` | nur JS |
| `BookingBasicReservation` | — | ungemappt → `.other` | nur JS |
| `RocketMilesReservation` | `ROCKET_MILES` | ungemappt → `.other` | nur JS |
| `PublicTransportReservation` | `PUBLIC_TRANSPORT` | ungemappt → `.other` | nur JS |
| `SingleTripInsuranceReservation` | `SINGLE_TRIP_INSURANCE` | ungemappt → `.other` | nur JS |

Nav-Einträge „Attraktionen“ / „Mietwagen“ / „Flughafentaxis“ sind **Verkaufs-Verticals**, keine My-Trips-Buchungen.

## Feldinventar

### `PrebookTaxiReservation` (Live, dieses Konto)

Gemeinsame Reservation-Felder: `__typename`, `verticalType`, `bookingUrl`, `startDateTime`, `endDateTime`, `reservationStatus`, `price.{amount,currency}`, `identifiers.{publicId,publicFacingIdentifier}`.

Typ-spezifisch: `bookingRef`, `pickUp.location.{city,airportCode,airportName}`, `dropOff.location.city`, `product.{providerName,vehicleTypeText}`.

MFE fragt zusätzlich `bookerEmail` — **nicht** im Produktiv-Query (PII).

### `AttractionReservation` / `CarReservation` (MFE-Query, keine Live-Zeile)

- Attraction: `ticketCount`, `product.{name,location.city}`
- Car: `pickUpLocation.city`, `dropOffLocation.city`, `product.{carClass,name,supplier}`

Tests gegen schema-aligned Fixtures, nicht gegen dieses Konto.

## Query-Shape 2026-08 vs. Code

| Element | Live MFE | Code vorher | Code jetzt |
|---------|----------|-------------|------------|
| Operation | V1 `GetTripsQuery` + `SingleTimelineQuery` **und** V2 `SingleTimelineQueryV2` / `singleTripTimelineQueriesV2` | nur V1 | V1 bleibt (Live-V1 lieferte alle 51 Reservierungen) |
| `supportedExperiences` (V1-`P`) | `ACCOMMODATION_ARRIVAL`, `INSTAY`, `PRETRIPS`, `BHOME_ARRIVAL`, `POST_TRIP`, `TAXI_ARRIVAL` | identisch | identisch (SSOT `timelineSupportedExperiences`) |
| `ATTRACTION_ARRIVAL` / `CAR_ARRIVAL` | Enum im Chunk, **nicht** im V1-`P`-Array | nicht gesendet | weiterhin nicht (keine V1-Abweichung) |
| `supportedConnectors` | volles `R`-Array inkl. `TAXI_COMPANION`, `AIRPORT_TRANSPORTATION_RECOMMENDATION`, … | Teilmenge (HAR 2026-07) | Live-`R`-Liste |
| `supportedConnectorsVariant` | `B4B_EXPENSE_MANAGEMENT_FEATURE_INTEREST` | fehlt | nicht nötig für V1 |
| `thumbnailSize` | 2192×548 | 2192×548 | unverändert |
| WAF | `challenge.js` + Cookie; GraphQL ohne extra WAF-Header | In-Page-fetch | unverändert |
| Fragmente | Accommodation, RTB, Basic, RocketMiles, Attraction, Car, Flight, PrebookTaxi, PublicTransport, Insurance | nur Hotel + Flug | Hotel, Flug, Attraction, Car, PrebookTaxi |

## Umsetzung

- Taxi: Katalog-Felder aus Live-Inventar; `BookingType.other` (kein Taxi-Enum).
- Attraction/Car: Fragmente + Mapping, damit spätere Upcoming-Buchungen nicht als generisches `.other` ohne Felder landen.
- Fixtures: `Tests/ReisenBookingComTests/Fixtures/single_timeline_{taxi,attraction,car}_sample.json`

## Hausregeln / Confirm-HTML (DE, Live 2026-08-28)

Bestätigung `confirmation.de.html`, Tab **Richtlinien der Unterkunft**: generisches FAQ, keine Unterkunfts-SSOT. Haustier-FAQ verweist auf Listing **„Zu beachten“** — das fetch’t der Enrich-Pfad nicht.

Sichtbar auf derselben Confirm-Seite (nicht im FAQ-Tab):

| Block | Inhalt | Extractor |
|-------|--------|-----------|
| **Wichtige Information** (Singular) | Ankunftszeit im Voraus; Lichtbildausweis + Kreditkarte | `BookingComGuestHintParser` (`arrival:in_advance`, `checkin:photo_id`); Check24/Opodo nur `StayHintHTMLExtractor.extract` |
| **Hotelrichtlinien** | nur Parken + WLAN | kein Prep-Hint |
| Zimmer-Ausstattung | Handtücher/Bettwäsche **enthalten** | kein Linen-Hint (Needles nur „nicht gestellt“ / Extra-Fee) |
| Raucher/Nichtraucher | Nichtraucherzimmer (Amenity) | kein Hint |
| FAQ Haustiere | „siehe Zu beachten“ / EN „if pets are allowed“ | kein Hint (`pets are allowed` ist kein Needle) |
| FAQ Photo-ID | EN „photo identification“ / „valid photo ID“ | kein Hint (Needles `photo id and credit` / `photo identification and credit`) |
| `<script>` i18n `pet_fees` | „Haustiere willkommen…“ | wird vor dem Flatten entfernt |

Haustiere nur, wenn die **sichtbare** Confirm-HTML eine echte Regel enthält (`Haustiere sind nicht erlaubt` / `Haustiere willkommen`), nicht aus FAQ oder i18n. Listing-„Zu beachten“ bleibt Lücke.

Enrich: nur `.hotel` und `.flight`. Car/Attraction/Taxi rufen keine Hotel-Confirm auf.
