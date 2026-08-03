# Implementation-Spec: `BookingType.activity`

Status: **Implementiert** (gemeinsame Basis für Airbnb Experiences + GetYourGuide).  
Ausführungsreihenfolge: [`provider-activity-implementation-plan.md`](provider-activity-implementation-plan.md) Phase 0.  
Details Provider: [`airbnb-experiences-impl-spec.md`](airbnb-experiences-impl-spec.md), [`getyourguide-impl-spec.md`](getyourguide-impl-spec.md).

## Ziel

Erlebnisse/Activities als eigenen Buchungstyp führen (heute nur `flight | hotel | ferry | other`; Airbnb Experiences landen als `.other`).

## Domain

Datei: `Sources/ReisenDomain/Entities/BookingEnums.swift`

```swift
public enum BookingType: String, … {
    case flight
    case hotel
    case ferry
    case activity  // neu
    case other
}
```

- Codable/`rawValue` = `"activity"` (stabil für SwiftData `bookingTypeRaw`).
- Alle `switch`/`CaseIterable`-Stellen aktualisieren (Domain-Tests, Mapper, UI).
- Exhaustive-Switch-Regel: neue Cases müssen kompilieren (Default nur wo fachlich `.other`-äquivalent).

## Persistenz / Schema

- `SDBooking.bookingTypeRaw` speichert String — **keine** Schema-Migration nötig, wenn nur neuer Raw-Wert.
- Bestehende Experiences in DB mit `other` bleiben bis Re-Sync; optional einmaliger Repair-Pfad (nicht Pflicht).

## UI / SharedUI

| Stelle | Soll |
|--------|------|
| Booking-Editor Typ-Picker | „Erlebnis“ / Activity |
| Listen/Details | Typ-Label + passende Zeitdarstellung (Event-Fenster, kein Hotel-Check-in) |
| `BookingScheduleFields` | `.activity` wie Flug/Event: Ortszeit Start/Ende; kein Check-in/out-Zwang |
| Gap-Deep-Links | vorerst keine Activity-Suche (optional später GYG/Viator) |
| Timeline / Offen | Activity wie andere zukünftige Buchungen |

## Provider-Anbindung

Reihenfolge und Phasen: [`provider-activity-implementation-plan.md`](provider-activity-implementation-plan.md).  
Diese Spec definiert nur den Domain-/UI-Vertrag für `.activity`.

## Tests

- Domain: `BookingType.activity` round-trip / displayLabel falls eingeführt.
- Airbnb: Fixture → Draft `.activity`.
- Schedule-Felder: Activity ohne Hotel-Check-in-Minuten.

## Nicht in Scope

- Neuer Typ Mietwagen/Bahn (separater Check24-Audit).
- Opodo-Änderungen.
- Partner-APIs.
