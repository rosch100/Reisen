# Implementation-Spec: `BookingType.train`

Status: **Implementiert**  
Backlog: [feature-backlog.md](feature-backlog.md) F01  
Muster: [booking-type-activity-impl-spec.md](booking-type-activity-impl-spec.md)

## Ziel

Bahn als eigenen Buchungstyp führen (Zugnummer, Bahnhof, Sitz/Klasse, Betreiber). DACH-Reisen ohne Bahn sind unvollständig; `.other` macht Transport-Gaps unscharf.

## Domain

Datei: `Sources/ReisenDomain/Entities/BookingType.swift`

- `case train` nach `ferry` (`CaseIterable`-Reihenfolge = Picker)
- `rawValue` = `"train"` (SwiftData `bookingTypeRaw`, keine Migration)
- `usesFlightLikeSchedule` / `isTransport`: Flug, Fähre, Bahn
- `systemImageName`: SharedUI (`BookingType+SystemImage`, Symbol `train.side.front.car`)

## Persistenz

- `SDBooking.bookingTypeRaw` — **keine** Schema-Migration
- Felder auf bestehenden Spalten: `title`, `locationFrom`/`locationTo`, `operatorName`, `rateDetails.roomCategory`, `startAt`/`endAt`, optionale Flight-Offsets

## UI / SharedUI (HIG)

| Stelle | Soll |
|--------|------|
| Typ-Picker | `Label(displayLabel, systemImage:)` für alle Typen |
| Editor | Von/Nach Bahnhof, Betreiber, Sitz/Klasse; DatePicker-Titel = Abfahrt/Ankunft |
| Details | `BookingScheduleFields` über `usesFlightLikeSchedule` |
| Timeline macOS | Copy wie Fähre; Typ-Caption mit Symbol |
| iOS Listen | `OpenBookingRow`: Symbol + Uhrzeit bei flight-like |
| iOS Detail | `BookingTypeLabel` in Typzeile |

Kein DB-Branding, kein Icon-only-Picker, kein paralleles Timeline-Layout nur für Bahn.

## Zeitmodell

- `BookingTimeNormalizeDispatch`: `.train` wie Flug/Fähre (`BookingFlightTimeNormalizer`)
- Ohne Offsets: unverändert (manuelle DACH-Zeiten)
- `FlightTimeZoneAssigner`: unverändert (IATA-only)

## Gaps

- `GapKindClassifier.isTransport` → `BookingType.isTransport`
- Flug↔Bahn = `.lodging`

## Provider

| Provider | Status |
|----------|--------|
| Traveloka | `TRAIN` / `TRAIN_GLOBAL` → `.train` (Titel aus `productName`; Stations-Parser folgt mit HAR) |
| Check24 | **kein** Mapping — Live 2026-08-28: `train`/`bahn`/`rail` in 64 Activities nicht gesehen ([check24-productkey-audit.md](check24-productkey-audit.md)) |
| Opodo | **kein** Mapping — `rail` in HAR nicht als Booking beobachtet |
| Booking.com / Airbnb | kein Bahn-Vertical in den belegten Typ-Mappern |

Manuell und F06 Paste-Import bleiben zusätzliche Quellen. Kein DB/ÖBB-Adapter.

## Tests

- `BookingTypeTests`: rawValue, Labels, `usesFlightLikeSchedule`
- SharedUI: `systemImageName`, `presentationTitle`
- `GapKindClassifierTests`: hotel/flight/train-Kombinationen
- `BookingTimeNormalizerDeadlinesTests`: train mit/ohne Offsets
- `BookingScheduleFieldsTests`: Bahnhof-Labels, Abfahrt/Ankunft
- `L10nTests`: neue Keys de/en

## Nicht in Scope

- EventKit-Abfahrt für Bahn
- Repair bestehender `.other`-Bahnbuchungen
- `carRental` als Gap-Transport
