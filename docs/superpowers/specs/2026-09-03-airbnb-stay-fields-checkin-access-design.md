# Design: Airbnb Stay/Experience Feldfüllung + `checkInAccess`

**Datum:** 2026-09-03  
**Status:** Entwurf (brainstorming freigegeben; Spec-Review CodeRabbit-Findings eingearbeitet)  
**Priorität:** Stay-`locationToAddress` vervollständigen (Map-`address`-Fallback)

## Problem

Airbnb liefert in Browser/API mehr Buchungsdaten als der Sync nutzt. Teile sind schon verdrahtet; die Spec trennt **Ist** und **Delta**.

### Stay — Ist (bereits im Code)

| Thema | Code |
| --- | --- |
| Adresse `oneLine` → `multiLine` | `AirbnbTripDetailsParser`: `NonEmpty.first(oneLineAddress, joinedMultiLineAddress)` |
| Enrich → Draft | `AirbnbStayEnrichment.facts`: `locationToAddress: tripDetails.oneLineAddress` |
| Gäste / Zimmer | Parser + Enrich: `guestAdults` / `roomCount` → `BookingRateDetails` |

### Stay — Delta (offen)

- **Map-`address`:** `GuestFacingLocation` modelliert kein Map-`address`. Fehlen `oneLine` und `multiLine`, bleibt `locationToAddress` leer, obwohl die Portal-Karte eine Straße hat.
- Listing-Titel: Katalog nutzt oft `displayName` (Ort); `metadata.title` / Marquee-Titel werden nicht in Enrich-`title` übernommen.
- Check-in-Methode und Zugang (`check_in_method`, `hidden_checkin_guide`, optional Passcode): kein Domain-Feld.

### Experience — Delta (offen)

- Host-Name → `operatorName` ungenutzt; Overview nur als GuestHint bei Prep-Keywords.
- `experienceWebPath` geparst, nicht an `externalUrl` (bewusst; RO bleibt Portal).
- Storno-Frist nur EN-`cancel by` (DE Follow-up).

## Ziele

1. Stay-Adresse: Fallback-Kette vervollständigen mit Map-`address` (höchste Prio).
2. Stay-Titel aus `metadata.title` (Fallback Marquee).
3. Neues Domain-Feld `checkInAccess` (Freitext: Methode + Anleitung + Code, **ohne WLAN**).
4. Experience: Host → `operatorName`; Overview nur als GuestHint bei Prep-Keywords.
5. UI: `checkInAccess` in Buchungsdetail + Editor (Hotel + Activity); kein Kalender/EventKit.
6. Sync-Semantik für `checkInAccess` explizit (siehe Entscheidungen).
7. Logging: nur Presence (`present`/`missing`), nie Klartext-Zugang/Adresse in Diagnose-Reasons.
8. Fehler-/GitHub-Auto-Report: `checkInAccess`, Adressen und Airbnb-JSON-Fragmente dürfen nie in
   `LocalizedError`/`NSError`-Meldungen, `technicalDetails`, Sync-Log-Klartext oder Issue-Bodies landen;
   Defense-in-Depth über `SecretRedactor`/`DiagnosticRedactor` (Labels + JSON-Keys).

## Nicht-Ziele

- WLAN (`hidden_wifi_info`) speichern.
- Koordinaten, Betten-/Bad-Anzahl (kein Domain-Feld außer `roomCount` = Schlafzimmer).
- Passagier-Namen aus `travelers` (PII; Anzahl über `guestCount`).
- Stay-`cancellationUrl` ohne belegte HTTPS-`web_url`.
- DE-Storno-Textparser für Experiences (eigenes Follow-up).
- Andere Provider in derselben Welle (Schema gilt hotel/activity global; Füllung zuerst Airbnb).
- Kalender-Notizen mit Zugangscode.
- Verschlüsselung von `checkInAccess` in SwiftData/CloudKit jenseits der normalen Container-Absicherung (kein separates Keychain-Feld in v1).

## Entscheidungen

| Thema | Wahl |
| --- | --- |
| Datenmodell Zugang | Ein optionaler String `checkInAccess` |
| Inhalt Zugang | Methode + Anleitung + Code; optional Anfahrt (`host_directions`); **kein** WLAN |
| Buchungstypen | Hotel + Activity (Labels je Typ) |
| UI | Detail + Editor; kein EventKit |
| Stay-Adresse | **Ist:** `oneLine` → `multiLine`. **Delta:** sonst Map-`address` |
| Stay-Ort vs. Adresse | `locationTo` = Ort/`displayName`; Straße nur in `locationToAddress` |
| Stay-Titel | Enrichment-`title` aus `metadata.title` (Fallback Marquee-Titel) |
| Experience-Portal-URL | `externalUrl` bleibt Trip-RO; PDP nicht überschreiben |
| Experience-Host | `operatorName` aus Marquee „Hosted by …“ / Host-Header wenn belegbar |
| Secrets in Logs | nur Flags, keine Codes/Adressen |
| Sync `checkInAccess` | siehe Abschnitt Sync-Semantik |
| Schutz `checkInAccess` | siehe Abschnitt Schutz und Aufbewahrung |

### Sync-Semantik `checkInAccess`

`SyncBookingDraftFieldCopy.applyCoreFields` kopiert Scalars heute 1:1. Für `checkInAccess` gilt **nicht** blindes Überschreiben mit `nil`/leer:

| Draft (nach Enrich) | Bestehender Booking-Wert | Ergebnis |
| --- | --- | --- |
| non-empty | beliebig (inkl. manuell) | Provider-Wert gewinnt |
| `nil` oder leer | non-empty (manuell oder älterer Sync) | **behalten** — Sync löscht keinen Zugang |
| `nil` oder leer | `nil`/leer | bleibt leer |

Begründung: Enrichment darf fehlende Provider-Teile nicht als „gelöscht“ interpretieren. Analog zu Enrichment-Mustern, die leere Incoming-Werte nicht über vorhandene legen. Implementierung: in `applyCoreFields` (oder speziellem Helper) nur setzen, wenn `NonEmpty.string(draft.checkInAccess) != nil`.

Akzeptanztest: Booking mit manuellem `checkInAccess` → späterer Sync mit leerem Provider-Feld → Wert unverändert.

### Schutz und Aufbewahrung `checkInAccess`

Der Wert kann Passcodes enthalten. Regeln für v1:

| Pfad | Verhalten |
| --- | --- |
| Persistenz (`Booking` / `SDBooking`) | Optionaler String im normalen SwiftData-/CloudKit-Store (wie Bestätigungscode); kein separates Keychain |
| iCloud-Sync | Wie andere Booking-Scalars im Cloud-Store; nur Geräte des Nutzers |
| Diagnose / Sync-Log | Nur `present`/`missing`; kein Klartext |
| Crash-Pending / GitHub-Issue / Auto-Report | Klartext ausgeschlossen (`SecretRedactor` / Labels); niemals in `technicalDetails` |
| UI Copy | Erlaubt (Nutzeraktion), Standard-`FieldCopyKind` wie andere sensible Identifiers |
| Suche / Filter | Kein Index, kein Spotlight, kein Export-Pfad in v1 |
| Backup | Mit dem App-Container (iCloud/Gerätebackup); keine App-eigene Extra-Retention |
| Löschung | Mit Buchung / Nutzer-Reset / Store-Löschung; keine längere Aufbewahrung außerhalb des Stores |

WLAN bleibt out of scope. Passcodes in `checkInAccess` sind bewusst Nutzerdaten auf dem Gerät — nicht „öffentliche“ Diagnosedaten.

## Architektur

```text
Airbnb TripDetailsQuery + stay_reservation_details / activity_reservation_details
        │
        ▼
Parser (Adresse inkl. Map-Fallback, Zimmer, Gäste, Titel, checkInAccess-Teile, Host, …)
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

### Stay-Adresse (Fallback-Kette)

1. `guestFacingLocation.oneLineAddress` — **Ist**
2. sonst `multiLineAddress` joined — **Ist** (`AirbnbTripDetailsParser`)
3. sonst Map-`address` (DTO erweitern, Parser + Tests) — **Delta**

Enrichment weist weiter `locationToAddress` aus dem Parser-Ergebnis zu.

### Airbnb Stay-Enrich (Delta)

| Feld | Quelle | Hinweis |
| --- | --- | --- |
| `locationToAddress` | Map-`address` als 3. Fallback | Prio #1; 1+2 bereits Ist |
| `title` | `metadata.title` → Marquee `title` | überschreibt Orts-Titel |
| `checkInAccess` | `check_in_method` + `hidden_checkin_guide` (+ Passcode) + optional `host_directions` | kein `hidden_wifi_info` |

**Kein Delta mehr:** `guestCount` / `roomCount` (bereits Enrich).

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
- Adresse/Titel/Gäste/Zimmer: bestehende UI-Felder — nur Datenfüllung bzw. Titel-Delta.

## Fehler & Leere Quellen

- Fehlende Stay-Adresse nach vollständiger Kette → Feld bleibt `nil`, Diagnose `location_to_address_missing` (ohne PII).
- Fehlende Zugangsteile → `checkInAccess` nur aus vorhandenen Teilen; alles leer → `nil` (löscht bestehenden Wert beim Sync nicht).
- `house_manual` fehlt auf manchen Buchungen → kein Fehler.
- Parser-/Sync-Fehler: keine Klartext-Codes, Adressen oder Roh-JSON in `Error.localizedDescription`,
  `GitHubIssueErrorText.dump`, Sync-Log-Zeilen oder Auto-Report-Bodies — nur stabile Reason-Codes
  bzw. `present`/`missing`.

## Tests

- Stay: Fixture mit nur Map-`address` → `locationToAddress` gesetzt; Fixture mit `oneLine` bevorzugt vor Map.
- Stay: Fixture `oneLine` / nur `multiLine` / nur Map — alle drei Quellen und Fallback-Reihenfolge.
- Stay: Titel, `checkInAccess` ohne WiFi-Substring.
- Stay: WiFi-Row in Fixture → `checkInAccess` enthält sie nicht.
- Sync: manueller `checkInAccess` bleibt, wenn Provider später leer liefert; non-empty Provider überschreibt.
- Experience: `operatorName` aus Host-Text; Overview ohne Prep-Keywords → keine Hint.
- Domain/UI: Mapper + Editor/Detail-Identifier falls nötig (`UITestingIdentifiers`).
- Logging: Assert auf Presence-Reason, nicht auf Klartext.
- GitHub-Auto-Report: simulierter Parser-Fehler mit synthetischem Passcode/Adresse → Issue-Body und
  Technical Details enthalten den Klartext nicht (`SecretRedactor`-Tests).

## Akzeptanz

1. Nach Airbnb-Stay-Sync hat die offene Hotelbuchung eine `locationToAddress`, wenn eine der drei Adressquellen greift (inkl. Map-only).
2. Listing-Titel und Check-in-Zugang (ohne WLAN) sind gefüllt, soweit die API sie liefert; Gäste/Zimmer bleiben wie bisher.
3. Experience setzt Host als `operatorName`, wenn ableitbar.
4. Manuelles `checkInAccess` bleibt bei leerem Provider-Sync; non-empty Provider überschreibt.
5. Keine WLAN-Codes und keine Adress-/Code-Klartexte in DiagnosticLogger-Reasons.
6. Keine `checkInAccess`-/Adress-/Passcode-Klartexte in Sync-Fehlertexten oder GitHub-Auto-Reports
   (auch wenn „Fehler automatisch senden“ aktiv ist).

## Out of scope / Follow-ups

- DE Experience-Cancel-Policy-Parser
- Stay-Storno-URL ohne HTTPS-Beleg
- Andere Provider für `checkInAccess`
- EventKit-Mitnahme des Zugangstexts
- Keychain-/Crypto-Sonderpfad für Passcodes (nur wenn Produkt das später verlangt)
