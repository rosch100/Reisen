# Architektur (Domain-first)

## Module

| Modul | Abhängigkeit | Rolle |
|-------|--------------|--------|
| ReisenDomain | Foundation | SSOT: Entities, Repository-/Side-Effect-Ports, Use Cases |
| ReisenData | Domain, SwiftData | Persistenz-Adapter, Hybrid-Stores V7 (`reisen-cloud` / `reisen-local`), Mapper |
| ReisenProviders | Domain | `TravelProvider`, Registry |
| ReisenAppCore | Domain, Data, Providers | Bootstrap, SyncStore, EventKit/Reminder Side Effects |
| ReisenCheck24 | Domain, Providers, WebKit | Erste Provider-Implementierung |
| Reisen | alle | macOS Composition Root + UI (nutzt `AppBootstrap` / CloudKit hybrid) |

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
