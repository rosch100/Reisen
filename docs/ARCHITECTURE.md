# Architektur (Domain-first)

## Module

| Modul | Abhängigkeit | Rolle |
|-------|--------------|--------|
| ReisenDomain | Foundation | SSOT: Entities, Repository-/Side-Effect-Ports, Use Cases, `ProviderID` |
| ReisenData | Domain, SwiftData | Persistenz-Adapter, Hybrid-Stores V7 (`reisen-cloud` / `reisen-local`), Mapper |
| ReisenProviders | Domain | `TravelProvider`, `ProviderRegistry`, Deep-Link-Ports |
| ReisenAppCore | Domain, Data, Providers | Bootstrap, SyncStore, EventKit/Reminder Side Effects |
| ReisenCheck24 | Domain, Providers, WebKit | Check24 Sync |
| ReisenOpodo | Domain, Providers, WebKit | Opodo Sync |
| ReisenBookingCom | Domain, Providers, WebKit | Booking.com Sync |
| ReisenAirbnb | Domain, Providers, WebKit | Airbnb Sync (Stays + Experiences) |
| ReisenGetYourGuide | Domain, Providers, WebKit | GetYourGuide Sync |
| ReisenTraveloka | Domain, Providers, WebKit | Traveloka Sync |
| Reisen | alle | macOS Composition Root + UI |
| ReiseniOS | alle | Universal iOS/iPadOS App |

Registrierte Sync-Anbieter (SSOT): `ProviderID.syncProviderIDs` — Check24, Opodo, Booking.com, Airbnb, GetYourGuide, Traveloka. Wiring in `AppBootstrap.makeProviderRegistry()`.

CloudKit-/Store-Details: [`docs/dev/swiftdata-hybrid-cloudkit.md`](dev/swiftdata-hybrid-cloudkit.md).

## Regeln

- Domain kennt weder SwiftData noch WebKit.
- Provider liefern `ProviderBookingDraft`; Persistenz läuft über Use Cases.
- Store-Init ohne stilles Löschen/In-Memory; Reset nur über explizite Nutzeraktion.
- Settings-Keys: `AppSettingsKeys` (SSOT).

## Zeit-Kontrakt (wichtig für Storno/Erinnerungen)

- `startAt` / `endAt` und `CancellationDeadline.deadlineAt` werden als **absolute Instants** gespeichert, damit Vergleiche zu `now`, Kalender-Events und Erinnerungen stabil sind.
- Für die Anzeige-orientierte Wall-Clock wird zusätzlich `hotelOffsetSeconds` persistiert.
- Vor jedem DB-Write müssen Provider-Rohdaten in einen kanonischen Zustand überführt werden (mindestens: fehlende `hotelOffsetSeconds` für Deadlines setzen, Zeitfelder konsistent machen).
