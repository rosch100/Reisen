# Implementation-Spec: ProviderBookingFacts + DraftAssembler

Status: **Implementiert**  
Stand: 2026-08-27

## Ziel

Provider liefern nur I/O und Extraktion ihrer API-Form in `ProviderBookingFacts`. Semantik (DateWindow, Status, TravellerType, BaggageType, Needs, Draft-Assembly, Merge) liegt in `ReisenDomain`.

Ein neuer Provider: Session + Fetch + Extract nach Facts. Kein DateWindow, kein Status-Switch, kein `needsDraftEnrichment`-Override.

## Schichtgrenze

| Schicht | Darf | Darf nicht |
|---------|------|------------|
| Provider | Session, HTTP/WebView, Parse der eigenen JSON/HTML-Form in Facts oder Domain-Parser-Aufrufe | DateWindow, Status-Enum-Logik, TravellerType-Token, Needs, Draft-Felder semantisch zusammenbauen |
| Domain | `DraftAssembler`, `BookingDateWindow`, Keyword-Parser, `DraftEnrichmentNeeds`, `ProviderBookingDraft.apply` | Endpoints, DOM-Marker, Provider-DTOs |
| SyncStore | Catalog → Needs → Detail-Fetch → apply → Persist | Provider-`if` |

## `ProviderBookingFacts`

Kanonisches Zwischenmodell (`Sources/ReisenDomain/Sync/`):

- Identität: `provider`, `bookingType` (Typ-**Vokabular** bleibt Provider), `externalUrl`, `confirmationCode`, `title`, Locations, `operatorName`
- Zeit als `TemporalFact`, nicht als fertiges `startAt`/`endAt`:
  - `iso(String)` — wenn der Provider Roh-ISO hat (Booking.com GraphQL)
  - geparste `Date`s immer über `TemporalFact.pair(bookingType:start:end:)` — Domain macht Hotel → `hotelDay`, sonst Instant
  - `wallClockAsUTC` nur intern im ISO-Pfad
- `statusRaw` — Rohstring(s) aus der API; Domain parst via `BookingStatus.parse` / `parse(parts:)`
- `deadlines` (Provider parst Policy-Text; Domain mapped strukturierte Felder)
- `rateDetails`, Passengers, GuestHints, Offsets, Check-in-Minuten, Fingerprint

`bookingType(of:)` bleibt Provider: `"Flight"` / `"ACCOMMODATION"` / Traveloka-Product-Strings sind kein Domain-Vokabular. Katalog- und Detail-Mapper (Airbnb, GYG, Opodo, Booking.com, Traveloka, Check24, billiger-mietwagen.de) rufen nur `DraftAssembler` — kein paralleles `ProviderBookingDraft(`- oder `ProviderBookingEnrichment(`-Init.

## DateWindow (analog `BookingTimeNormalizeDispatch`)

| `BookingType` | Regel |
|---------------|--------|
| `.hotel` | Kalendertag via `HotelStayDate`; Uhrzeit/TZ verwerfen; Offset aus ISO merken |
| `.flight`, `.ferry` | Wanduhr als UTC-Instant + Offset (Normalizer zieht Offset später ab) |
| `.activity`, `.carRental`, `.other` | wie Flug-artig (ISO → Wall-Clock-Storage), ohne Pflicht-Flug-Offsets |

`TemporalFact.pair` ist die Extract-API für geparste `Date`s. `BookingDateWindow.resolve` kanonisiert Hotels immer auf `HotelStayDate.calendarDay` (mit Offset: Ziviltag in Hotel-TZ; ohne Offset: GMT-Anker). Extract wählt nicht zwischen Instant und HotelDay und ruft kein `dateOnly` vor `pair`. Roh-ISO weiter als `.iso`.

Stay-`hotelOffsetSeconds` nur bei `.hotel`: Facts, sonst DateWindow, sonst erste Deadline mit Offset. Andere Typen ignorieren den Stay-Offset (Flug/Fähre haben eigene Offsets).

Fehlende Start- oder End-Fakten → kein Draft (`nil`), kein Dummy-Datum. Traveloka: fehlendes `itineraryTimestampEnd` überspringt den Eintrag. GetYourGuide: fehlendes `bookingFinishDate` überspringt den Eintrag (kein Start-Klon). `CatalogListing.shouldDrop` (storniert, `done`/`ended`) gilt im Assembler für jeden Katalog — ein kaputtes ISO darf den ganzen Katalog nicht abbrechen. Extract-Fehler (z. B. fehlende Booking-IDs) dürfen nicht per catch-all verschluckt werden. `requireDraft` nur, wo fehlendes Fenster ein harter Einzelfehler ist (Tests, Single-Item); storniert/abgeschlossen → `droppedFromCatalog`. Check24 filtert zusätzlich Start nicht vor heute (I/O, vor dem Assembler): Hotels am Kalendertag (`HotelStayDate.parse`-Präfix, Gate über `calendarDay`), andere Typen am Instant. Hotel-ISO mit Offset-Suffix (`…T00:00:00+07:00`) bleibt über das Datumspräfix parsebar.

`ISODateTime.offsetSeconds`: trailing `Z` → `0`; `±HH:MM`/`±HHMM` (auch nacktes `+0800`) → Sekunden; ohne Offset-Marker → `nil` (kein Dummy-UTC). Opodo-GraphQL (`parseInstant`) und Check24 (nach HTML-Capture von `cancelableUntilHotel`) rufen dieselbe Funktion; Opodo setzt `0` nur bei Epoch-ms bzw. explizitem Wall-Clock-UTC, nicht per `?? 0`. `ISODateTime.parseInstant`: Frac + Internet-DateTime + RFC-822-Offset (`+0800` / `+0000`), **kein** Day-Only und keine Wall-Clock ohne TZ (GYG-Decoder, Opodo-ISO-Zweig, Check24 `cancelableUntilHotel`). `ISODateTime.parseWallClockUTC`: `yyyy-MM-dd'T'HH:mm:ss` / Leerzeichen-Variante als UTC, **kein** Instant- oder Day-Only-Pfad (Opodo GraphQL ohne TZ, Check24 Katalog). `ISODateTime.wallClockStorage` nutzt Instant → Wall-Clock-UTC → Day-Only (nicht `parse`, sonst geht die Uhrzeit ohne Offset verloren). `HotelStayDate.parseGerman`: `dd.MM.yyyy` → GMT-Datumsanker (Opodo-/Check24-/Booking.com-Katalog). `ClockTime.minutes` / `minutes(fromHHMM:)`: Check-in/out als Minuten seit Mitternacht; Extract bleibt Capture (ISO-`T`, HTML-Regex, `"14:00-23:59"`).

`DraftAssembler.draft` setzt `CatalogListing.shouldDrop` für alle Kataloge durch. `DraftAssembler.enrichment` bleibt für Storno (Apply nach Detail-Fetch). Provider dürfen Enrichment nicht über `draft()` leiten, sonst fehlt das Cancel-Enrichment.

Booking.com Policy-Deadline-Offset kommt aus `ISODateTime.offsetSeconds(from: startISO)`, nicht aus einem Provider-`DateWindow`. Airbnb-Katalog gibt `listingTimeZone` als Offset an `TemporalFact.pair`. Rate-Coalesce nur über `BookingRateDetails.merging`. Frist-Dedup über `CancellationDeadline.deduped` / `uniquenessKey`. Passagier ohne Typ-Token → `TravellerType.unknown`, kein `.adult`-Default.

## Keyword-Parser (Domain)

- `BookingStatus.parseToken`: exakte Tokens (`CONFIRMED`/`ACTIVE`/`ISSUED`/`CONTRACT`/`UPCOMING`/`ACCEPT`/`ACCEPTED`/`CANCELLED`/`CANCELED`/`RETAINED`/`FINAL_RET`/`DIDNOTBUY`/`VOID`/…). Booking.com GraphQL `reservationStatus`; Airbnb Stay `ACCEPT`.
- `BookingStatus.parse` / `parse(parts:)`: Tokens zuerst (Storno vor Confirmed), danach Freitext (`cancel`/`refunded`/`storniert`/`voucher issued`, nicht `non-cancel`, nicht `refundable`, nicht `CANCELLABLE`, nicht `pending_cancellation`, nicht `CANCELLATION_AVAILABLE`, nicht `Stornierungsrichtlinie`).
- Traveloka-Tag-Listen (`itineraryTags`, `userTripStatus`) bleiben Extract: Rohstrings → `statusRaw`.
- `TravellerType.parse`: Token/Label (`adult`/`adt`, `child`/`chd`/`youth`, `infant`/`inf`/`baby`); sonst `unknown`.
- `BaggageType.parse`: `CHECKED_IN`/`CHECKED`/`CHECKED_BAG`/`checked-bag` → checkedBag; `HAND`/`CABIN`/`CABIN_BAG`/`carry-on` → cabinBag; `PERSONAL_ITEM`/`carry-on-small` → personalItem.
- `BookingBoardType.parse`: Enum-RawValues plus Opodo-Codes `BB`/`HB`/`FB`/`RO`. `parse(breakfastIncluded:)` für API-Bool (`true` → Frühstück, `false` → nur Zimmer, `nil` → unbekannt).
- `PlaceLabel.make(city:iata:)` — `"City (IATA)"`.
- `ClockTime.minutes(hours:minute:)` / `minutes(fromHHMM:)` — gültige Uhrzeit → Minuten seit Mitternacht; sonst `nil`.
- `HotelStayDate.parse` / `parseGerman` — `yyyy-MM-dd` bzw. `dd.MM.yyyy` → GMT-Datumsanker.
- `ISODateTime.parseInstant` — Frac + Internet-DateTime + RFC-822-Offset (`+0800`), kein Day-Only.
- `ISODateTime.parseWallClockUTC` — Wall-Clock ohne Offset als UTC; nicht über `parse`/`parseInstant`.
- `BookingIdentityKey.make` — `url:` sonst `conf:|start:`.
- `CancellationDeadline.firstHotelOffsetSeconds` auf Arrays.
- `CancellationDeadline.combining(refund:)` — vorhandene Free-/Fee-Fristen bleiben, Refund füllt Lücken (Traveloka Refund-HTML).
- `CancellationDeadline.deduped` / `uniquenessKey` — Frist-Dedup nach Zeitpunkt, Free/Fee, Strict, Betrag (Cent) bzw. Policy-Text. Opodo-HTML-Heuristik (gleiche Uhrzeit, Free/Policy bevorzugen) bleibt Extract.
- `BookingRateDetails.merging` — Incoming überschreibt, außer `boardType == .unknown`. Check24 Details-Merge und Airbnb GuestCount nutzen denselben Merge.
- `CatalogListing.shouldDrop` — storniert oder abgeschlossen (`done`/`ended`); `DraftAssembler.draft` setzt das für alle Provider durch. Check24 nutzt dieselbe Prüfung zusätzlich als I/O-Gate vor dem Detail-Walk.
- `CatalogListing.shouldFetchDetails` — nicht bei cancelled (Opodo Detail-HTML).
- `ProviderCatalog.dedupedByExternalURL`.

Sprachabhängiges HTML (`kostenlos` in Booking.com-Policy) bleibt Provider-Extract. Domain bekommt `isFreeCancellation` / `feeAmount` strukturiert.

## `DraftEnrichmentNeeds`

`DraftEnrichmentNeeds` ist das einzige Enrichment-Gate (Default `TravelProvider.needsDraftEnrichment`):

1. `requiresDeadlines &&` keine **nicht-freie** Deadline → enrich
2. Hotel ohne jede Deadline → enrich (Katalog hat die Storno-/Policy-Probe noch nicht geliefert, z. B. Opodo `getTrips`)
3. `status == .unknown` → enrich
4. Feldlücken **pro `BookingType`** (Hotel Check-in/Adresse/roomCategory, Flug Passengers/Airline, Activity operator/isAllDay/Passengers/Adresse, carRental operator/Locations, Fähre Titel + mindestens ein Port; beide Ports ohne Operator → Enrich, ein Port ohne Operator ist Katalog-vollständig).

Kein `CatalogEnrichmentMode`. Vollständiges Hotel **mit** mindestens einer Frist (confirmed, Adresse, Check-in/out, roomCategory) → kein Enrich, unabhängig vom Provider.

## Check24-Ausnahme

`fetchCatalog` läuft weiter über Hotel-/Non-Hotel-Detailseiten: die Activities-API hat Storno/Basket/Hints nicht. Basket-Gruppierung (`basketId` → eine Buchung, `roomItems`) bleibt Check24-Extract. Katalog-Walk bleibt Fetch: `CatalogListing.shouldDrop` plus Start nicht vor heute.

Mapping: `CancellationDeadline` / `BookingBoardType.parse` / `BaggageType.parse` / `BookingRateDetails.merging` (Details-Coalesce über `ParsedBookingDetails.merging`). Identität über `ParsedBooking.identityKey` → `BookingIdentityKey.make`. `enrichBooking` = Detail-Extract → `DraftAssembler.enrichment`.

## WebView-Session

`ProviderWebView.webView(from:orThrow:)` mappt fehlende Session auf den Provider-Error (`sessionNotEstablished` / `missingWebViewSession` / Airbnb `RepositoryError`). `webView(from:)` wirft `ProviderWebViewError.missingSession`. Booking.com (`BookingComWebViewSession`) und Check24 (`Check24WebSession`) behalten typisierte Wrapper.

SyncStore orchestriert Catalog → Needs → Detail-Fetch → apply ohne Provider-`if`. Enrichment-Diagnose-Log gilt für alle Provider.

## Tests

- Domain-Unit-Tests für Parser (`parse` vs `parseToken`), DateWindow, Needs, Assembler (Orakel: gleiche Fixtures → gleiche Draft-Felder).
- Needs-Orakel: vollständiges Hotel **mit Frist** → kein Enrich; Hotel ohne Fristen → Enrich (Storno-Probe).
- Bestehende Provider-Parser-/Catalog-Tests bleiben grün; kein stilles Umdeuten von Status oder Zeiten.
- Traveloka-Needs-Tests zeigen auf `DraftEnrichmentNeeds`.

## Nicht in Scope

- Schema-Migration, UI
- GraphQL-Queries, Wait-JS, Booking-Chooser, WAF/HAR
- Check24-Catalog-I/O aus `fetchCatalog` herausziehen
