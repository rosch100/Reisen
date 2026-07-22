# Architektur (Domain-first)

## Module

| Modul | Abhängigkeit | Rolle |
|-------|--------------|--------|
| ReisenDomain | Foundation | SSOT: Entities, Repository-/Side-Effect-Ports, Use Cases |
| ReisenData | Domain, SwiftData | Persistenz-Adapter, `ReisenSchemaV1`, Mapper |
| ReisenProviders | Domain | `TravelProvider`, Registry |
| ReisenCheck24 | Domain, Providers, WebKit | Erste Provider-Implementierung |
| Reisen | alle | macOS Composition Root + UI |

## Regeln

- Domain kennt weder SwiftData noch WebKit.
- Provider liefern `ProviderBookingDraft`; Persistenz läuft über Use Cases.
- Store-Init ohne stilles Löschen/In-Memory; Reset nur über explizite Nutzeraktion.
- Settings-Keys: `AppSettingsKeys` (SSOT).

## Zeit-Kontrakt (wichtig für Storno/Erinnerungen)

- `startAt` / `endAt` und `CancellationDeadline.deadlineAt` werden als **absolute Instants** gespeichert, damit Vergleiche zu `now`, Kalender-Events und Erinnerungen stabil sind.
- Für die Anzeige-orientierte Wall-Clock wird zusätzlich `hotelOffsetSeconds` persistiert.
- Vor jedem DB-Write müssen Provider-Rohdaten in einen kanonischen Zustand überführt werden (mindestens: fehlende `hotelOffsetSeconds` für Deadlines setzen, Zeitfelder konsistent machen).
