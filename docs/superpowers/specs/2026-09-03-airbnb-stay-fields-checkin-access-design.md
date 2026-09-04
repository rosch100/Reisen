# Design: Airbnb Stay/Experience Feldfüllung + `checkInAccess`

**Datum:** 2026-09-03  
**Status:** Entwurf (brainstorming freigegeben; Spec-Review ausstehend)  
**Priorität:** Stay-`locationToAddress` (Straße/PLZ/Ort aus Live-API)

## Problem

Airbnb liefert in Browser/API mehr Buchungsdaten als der Sync persistiert.

**Stay (live belegt, TripDetails + `stay_reservation_details`):**

- Straßenadresse in `guestFacingLocation.oneLineAddress` / `multiLineAddress` und Map-`address` — Enrichment setzt `locationToAddress` nicht (User-Beleg: offene Buchung hat Straße+PLZ+Ort).
- Listing-Titel in `metadata.title` / Marquee — Katalog nutzt `displayName` (Ort).
- `numberOfBedrooms` und `guestCountDetails.numberOfAdults` werden geparst bzw. geliefert, Stay-Enrich übergibt sie nicht.
- Check-in-Methode und Zugangsanleitung (`check_in_method`, `hidden_checkin_guide`, optional Passcode) existieren — kein Domain-Feld.

**Experience:**

- Treffpunkt/Adresse/Titel/Preis/Gäste weitgehend ok.
- Host-Name und ggf. Overview ungenutzt; `experienceWebPath` geparst, nicht verdrahtet.
- Storno-Frist nur EN-`cancel by` (DE Follow-up).

## Ziele

1. Stay-`locationToAddress` zuverlässig aus Provider-Daten füllen (höchste Prio).
2. Weitere bestätigte Stay-Lücken schließen: Listing-`title`, `guestCount`, `roomCount`.
3. Neues Domain-Feld `checkInAccess` (Freitext: Methode + Anleitung + Code, **ohne WLAN**).
4. Experience: Host → `operatorName`; Overview nur als GuestHint bei Prep-Keywords.
5. UI: `checkInAccess` in Buchungsdetail + Editor (Hotel + Activity); kein Kalender/EventKit.
6. Sync: Provider-Wert überschreibt immer, wenn non-empty.
7. Logging: nur Presence (`present`/`missing`), nie Klartext-Zugang/Adresse in Diagnose-Reasons.

## Nicht-Ziele

- WLAN (`hidden_wifi_info`) speichern.
- Koordinaten, Betten-/Bad-Anzahl (kein Domain-Feld außer `roomCount` = Schlafzimmer).
- Passagier-Namen aus `travelers` (PII; Anzahl über `guestCount`).
- Stay-`cancellationUrl` ohne belegte HTTPS-`web_url` (Cancel-Row hat live keine).
- DE-Storno-Textparser für Experiences (eigenes Follow-up).
- Andere Provider in derselben Welle (Schema gilt hotel/activity global; Füllung zuerst Airbnb).
- Kalender-Notizen mit Zugangscode.

## Entscheidungen

| Thema | Wahl |
| --- | --- |
| Datenmodell Zugang | Ein optionaler String `checkInAccess` |
| Inhalt Zugang | Methode + Anleitung + Code; optional Anfahrt (`host_directions`); **kein** WLAN |
| Buchungstypen | Hotel + Activity (Labels je Typ) |
| UI | Detail + Editor; kein EventKit |
| Sync-Konflikt | Provider überschreibt bei non-empty |
| Stay-Adresse | `oneLineAddress`, sonst `multiLineAddress` → Zeilen, sonst Map-`address` |
| Stay-Ort vs. Adresse | `locationTo` = Ort/`displayName`; Straße nur in `locationToAddress` |
| Stay-Titel | Enrichment-`title` aus `metadata.title` (Fallback Marquee-Titel) |
| Experience-Portal-URL | `externalUrl` bleibt Trip-RO; PDP nicht überschreiben |
| Experience-Host | `operatorName` aus Marquee „Hosted by …“ / Host-Header wenn belegbar |
| Secrets in Logs | nur Flags, keine Codes/Adressen |

## Architektur

```text
Airbnb TripDetailsQuery + stay_reservation_details / activity_reservation_details
        │
        ▼
Parser (Adresse, Zimmer, Gäste, Titel, checkInAccess-Teile, Host, …)
        │
        ▼
ProviderBookingFacts  (+ checkInAccess)
        │
        ▼
DraftAssembler.enrichment / draft
        │
        ▼
SyncBookingDraftFieldCopy → Booking / SDBooking
        │
        ▼
SharedUI Detail + Editor (L10n)
```

### Domain / Persistenz

- `Booking.checkInAccess: String?`
- `ProviderBookingDraft` / `ProviderBookingEnrichment` / `ProviderBookingFacts`
- `SDBooking.checkInAccess` + DomainMapper / FieldApply / Legacy-Copy wie andere Scalars
- `BookingType`: Labels für Hotel („Check-in / Zugang“) und Activity („Treffpunkt / Zugang“); Feld nur anzeigen wenn Typ hotel|activity **oder** Wert non-empty

### Airbnb Stay-Enrich (Delta)

| Feld | Quelle | Hinweis |
| --- | --- | --- |
| `locationToAddress` | `oneLineAddress` → sonst `multiLineAddress` joined → sonst Map `address` | Prio #1 |
| `title` | `metadata.title` → Marquee `title` | überschreibt Orts-Titel |
| `rateDetails.roomCount` | `roomsAndSpaces.numberOfBedrooms` | merge in bestehende RateDetails |
| `rateDetails.guestCount` | `guestCountDetails.numberOfAdults` | merge |
| `checkInAccess` | `check_in_method` + `hidden_checkin_guide` (+ Passcode wenn vorhanden) + optional `host_directions` | kein `hidden_wifi_info` |

Bestehend unverändert: Check-in/out-Minuten, Preis, Storno, `house_rules`/`house_manual`-Hints, Offset aus TZ.

### Airbnb Experience-Enrich (Delta)

| Feld | Quelle | Hinweis |
| --- | --- | --- |
| `operatorName` | Host aus Marquee/Host-Row | Activity persistiert Operator |
| `guestHints` | `event_overview` nur bei `BookingGuestHintPrepKeywords` | kein Dummy-Fließtext |

`experienceWebPath`: nicht an `externalUrl` hängen (RO bleibt Portal). Optional später eigenes Listing-Link-Feld — **YAGNI** in dieser Welle.

## UI

- Detail: `BookingRateField` wenn `checkInAccess` non-empty (nahe Bestätigungscode / Check-in).
- Editor: optionales mehrzeiliges Textfeld für Hotel + Activity.
- Adresse/Titel/Gäste/Zimmer: bestehende UI-Felder — nur Datenfüllung.

## Fehler & Leere Quellen

- Fehlende Stay-Adresse → Feld bleibt `nil`, Diagnose `location_to_address_missing` (ohne PII).
- Fehlende Zugangsteile → `checkInAccess` nur aus vorhandenen Teilen; alles leer → `nil`.
- `house_manual` fehlt auf manchen Buchungen → kein Fehler.

## Tests

- Stay: Fixture/TripDetails mit Adresse → Enrichment `locationToAddress` enthält Straße+PLZ-Muster (synthetisch, keine Live-PII).
- Stay: Titel, `roomCount`, `guestCount`, `checkInAccess` ohne WiFi-Substring.
- Stay: WiFi-Row in Fixture → `checkInAccess` enthält sie nicht.
- Experience: `operatorName` aus Host-Text; Overview ohne Prep-Keywords → keine Hint.
- Domain/UI: Mapper + Editor/Detail-Identifier falls nötig (`UITestingIdentifiers`).
- Logging: Assert auf Presence-Reason, nicht auf Klartext.

## Akzeptanz

1. Nach Airbnb-Stay-Sync hat die offene Hotelbuchung eine `locationToAddress` analog zur Portal-Adresse (Straße, PLZ, Ort).
2. Listing-Titel, Gästezahl, Zimmerszahl und Check-in-Zugang (ohne WLAN) sind gefüllt, soweit die API sie liefert.
3. Experience setzt Host als `operatorName`, wenn ableitbar.
4. Manuelles Editieren von `checkInAccess` wird beim nächsten Sync mit Provider-Wert überschrieben, wenn der Provider non-empty liefert.
5. Keine WLAN-Codes und keine Adress-/Code-Klartexte in DiagnosticLogger-Reasons.

## Out of scope / Follow-ups

- DE Experience-Cancel-Policy-Parser
- Stay-Storno-URL ohne HTTPS-Beleg
- Andere Provider für `checkInAccess`
- EventKit-Mitnahme des Zugangstexts
