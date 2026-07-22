# Opodo: Strukturierte Passagiere & Gepäck

## Ziel
Für Flugbuchungen sollen **Passagiernamen** und **Gepäckinformationen** aus Opodo-GraphQL (HAR) als **strukturierte Daten** in das Domain-Modell und in die Datenbank übernommen werden. Dadurch wird Synchronisierung zuverlässig und UI kann die Daten ohne „Parsing von Freitext“ darstellen.

## Nicht-Ziele (dieser Schritt)
- UI-Feinschliff über den grundlegenden Leseblock hinaus (später).
- Gepäck-Katalogisierungs-Logik für alle Anbieter (nur Opodo in diesem Schritt).

## Datenquellen (HAR)
Im HAR `www.opodo.de` (z. B. 2026-07-20, Flug SIN→CGK) werden folgende GraphQL-Operationen für Flugdetail-Daten genutzt:

1. `getTripByToken` (frontend-api/service/graphql)
   - liefert `travellers[]` inkl.:
     - `travellerType` (ADULT/…)
     - `title`, `name` (Display), `firstLastName`, `secondLastName`
     - `birthDate` (ISO-Zeitstring)
2. `baggageInfo` / `getBaggageInfo` (support-area-bff/service/graphql bzw. frontend-api/service/graphql)
   - liefert `baggageInfo(request: { tripDetailsToken })` inkl.:
     - `travellers[]` mit `numPassenger`
     - `sections[]` mit:
       - `airlineCode`
       - `baggageList[]`:
         - `type` (z. B. `CHECKED_BAG`, `CABIN_BAG`, `PERSONAL_ITEM`)
         - `numPieces`, `weight` (Gewicht in kg; bei unbekannt typischerweise `-1`)
         - `dimensions` (optional; häufig `null`)

## Domain-Design (SSOT)

### Neue Enums
- `TravellerType`: abgeleitet aus Opodo `travellerType` (ADULT/…); unbekannte Werte map werden als `.unknown` gespeichert.
- `BaggageType`: Map für Opodo `baggageList[].type`:
  - `CHECKED_BAG` → `.checkedBag`
  - `CABIN_BAG` → `.cabinBag`
  - `PERSONAL_ITEM` → `.personalItem`
  - sonst `.unknown`

### Neue Entities (unter `Booking`)
Die strukturierten Daten sollen als echte Domain-Listen abgebildet werden, ähnlich wie `cancellationDeadlines`.

#### `BookingPassenger`
- `id: UUID` (lokal)
- `bookingID: UUID?` (Sync)
- `passengerNumber: Int` → Quelle: `travellers[].numPassenger`
- `travellerType: TravellerType`
- `title: String?` → Quelle: `travellers[].title`
- `givenName: String?` → Quelle: `travellers[].name` (oder `firstLastName`-Logik später; für dieses Design wird das Display-Name Feld genutzt, da Opodo im HAR `name`/`firstLastName` getrennt liefert)
- `familyName: String?` → Quelle: `travellers[].firstLastName`
- `secondFamilyName: String?` → Quelle: `travellers[].secondLastName`
- `birthDate: Date?` → Quelle: `travellers[].birthDate`
- `baggageAllowances: [BaggageAllowance]`

#### `BaggageAllowance`
- `id: UUID` (lokal)
- `passengerID: UUID?` (Sync)
- `type: BaggageType`
- `pieceCount: Int?` → Quelle: `numPieces` (falls vorhanden)
- `weightKg: Double?`:
  - `-1` (Opodo „unknown“ in HAR) wird zu `nil` gemappt (kein Dummy).
- `sectionID: String?` → Quelle: `sections[].id` (Segmentbezug optional)
- `airlineCode: String?` → Quelle: `sections[].airlineCode`
- `fromLabel: String?` / `toLabel: String?` (optional; im HAR exemplarisch vorhanden, aber nicht zwingend. Dieses Design speichert nur, wenn vorhanden.)

### Kompatibilität zu bestehendem RateDetails
`BookingRateDetails` bleibt zunächst unverändert (SSOT für Preis/Boarding etc.).
- Bestehende Felder:
  - `airline`, `passengerCount`, `baggageInfoRaw` (optional)
- Neue Quelle (SSOT):
  - `passengerCount` kann bei strukturierten Passagieren weiterhin gesetzt werden, aber die „True Source“ für UI/Editor ist `booking.passengers`.
- `baggageInfoRaw` bleibt als Fallback/Debug:
  - wenn strukturierte Daten fehlen (z. B. anderer Providerpfad), kann der UI-Block weiterhin auf `baggageInfoRaw` zeigen.

## Persistenzdesign (SwiftData)

### Schema V3
Da neue Modelle eingeführt werden, wird das SwiftData-Schema von `ReisenSchemaV2` auf `ReisenSchemaV3` erweitert.

Neue `@Model`-Klassen:
1. `SDBookingPassenger`
   - Beziehung: `booking` (inverse `SDBooking.passengers`) mit `.cascade`
   - Felder wie im Domain-Design (mit Optionals)
2. `SDBaggageAllowance`
   - Beziehung: `passenger` (inverse `SDBookingPassenger.baggageAllowances`) mit `.cascade`
   - Felder wie im Domain-Design

### Upsert / Ersetzungsstrategie
Beim Sync:
- Passagiere und deren Gepäck werden **pro Booking vollständig ersetzt** (Replace-Strategy), um Duplikate zu vermeiden:
  - bestehende `SDBookingPassenger` für das Booking entfernen (cascade sorgt für Gepäck)
  - neue Liste anlegen

Begründung: Gepäcklisten hängen an dem Trip-Detail Token; Teil-Upserts sind fehleranfällig (z. B. Storno/Änderungen).

## Sync-Design (Datenfluss)

### Provider-Schnittstellen
Erweiterungen:
- `ProviderBookingDraft`: optional `passengers: [ProviderPassengerDraft]`
- `ProviderBookingEnrichment`: optional `passengers: [ProviderPassengerDraft]` (damit Enrichment den Katalog überschreiben kann)

### Opodo-Sync
Flug-Enrichment (für `bookingType == .flight`):
1. Katalog (`getTrips`):
   - bleibt „grob“ (start/end/title/status, plus `passengerCount`/Airline falls gewünscht)
2. Detail-Enrichment:
   - `getTripByToken` → strukturiere Passagiere
   - `baggageInfo` → strukturiere Gepäck je Pax (Join per `numPassenger`)
3. Merge:
   - `SyncStore` setzt `booking.passengers` auf die strukturierten Daten
   - `SyncProviderBookings` persistiert über den Repository-Mapper

### Fehlerbehandlung
- Wenn Passagiere aus `getTripByToken` nicht extrahierbar sind:
  - Enrichment wirft Fehler (kein Dummy-„leerer Passenger-List“-Silent-Fallback)
- Wenn Gepäck nicht verfügbar ist:
  - Passagiere werden trotzdem persistiert
  - Gepäck-Liste ist leer (oder `baggageAllowances` ohne Einträge)

## UI (nachgelagert, aber Felder definiert)

### TripDetail (Read)
- Für Flugbuchungen einen Abschnitt „Passagiere“:
  - pro Passenger: Name, Typ, Geburtsdatum (falls vorhanden)
  - darunter Gepäckzeilen je `BaggageAllowance`

### BookingEditor (Edit/Create)
- Liste „Passagiere“:
  - Hinzufügen/Löschen
  - pro Passenger: Felder + Gepäckzeilen
- SSOT: `passengerCount` aus `passengers.count` ableiten; freitext passengerCount wird nicht separat gespeichert.

## Tests
1. Domain/Mapper:
   - Persistenz-Roundtrip: Domain → SwiftData → Domain (Passagiere + Gepäck)
2. Opodo End-to-End:
   - HAR-Fixture → Parse+Enrich → Sync → DB-Felder
   - Prüfen:
     - Pax-Namen + Birthdate
     - Gepäcktypen + pieceCount
     - `weightKg`: `-1` → `nil`

## Open Questions
- Wie exakt „givenName“ zu „name“/„firstLastName“ im UI aussehen soll (HAR zeigt getrennte Felder; dieses Design speichert `familyName=firstLastName` und optional `givenName` aus dem Display-Name).
- Segmentbezug (`sectionID`/from/to): wird optional gespeichert; ob UI das braucht, klären wir später.

