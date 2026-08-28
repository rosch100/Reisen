# Check24 productKey-Audit

Status: **Live-Keys + Whitelist `rentalcar` + HTML-Detail-Parser** (2026-08-28).

Siehe Überblick: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § Check24.  
Fixture: [`../fixtures/provider-research/check24_activities_keys_redacted.json`](../fixtures/provider-research/check24_activities_keys_redacted.json).

## Live-Request (was die Seite feuert)

Eingeloggt auf `https://kundenbereich.check24.de/user/account/activities.html`. Performance/XHR:

| Request | Rolle |
|---------|--------|
| `GET https://kundenbereich.check24.de/kb/api/activities` | **Katalog** (64 Activities, vollständige Keys) |
| `GET https://kundenbereich.check24.de/kb/api/activity/center` | Center-Chips (Kategorien, keine product.keys) |
| `GET https://www.check24.de/ajax/user/activity/get/` | Homepage-Widget: `data.count=49`, nur **3** Activities im Array |

Rohpayload nicht committed (PII). Auswertung nur Keys/Häufigkeiten/URL-Muster.

## JSON-Form

| Endpoint | Shape | Casing |
|----------|--------|--------|
| `/kb/api/activities` | Top-Level `{ "activities": [...], "chips": [...] }` — **kein** `data.activities` | **camelCase** (`foreignId`, `startDate`, `productSpecificData`) |
| `/ajax/user/activity/get/` | `{ "status": 200, "data": { "count", "activities" } }` | **snake_case** (`foreign_id`, `start_date`, `product_specific_data`) |

Parser (`ActivityListParser+JSON`) unterstützt beide Pfade bereits.

`product` auf der KB-API: `{ key, label, productGroupKey, centerIdentifier }`.  
`link` ist Objekt `{ link, isBlank, isInternal }`, nicht String.

**PSD:** Auf der Live-KB-API nur `orderId` (in diesem Konto immer `null`). Die reichen `hotel_*` / `booking_uuid`-Felder sitzen in der Widget-snake_case-Antwort, nicht in `/kb/api/activities`.

## Alle `product.key` (64 Activities, inkl. ausgefilterte)

| `product.key` | n | Label | `productGroupKey` | Mapping heute | Status in diesem Konto |
|---------------|---|-------|-------------------|---------------|------------------------|
| `hotel` | 33 | Hotel | `hotel_holidayflat` | `.hotel` | ended 19, cancelled 14 |
| `rentalcar` | 9 | Mietwagen | `rentalcar` | `.carRental` | ended 4, cancelled 5 |
| `holidayflat` | 6 | Ferienwohnung | `hotel_holidayflat` | `.hotel` | ended 5, cancelled 1 |
| `power` | 6 | Strom | `energy` | verworfen (kein Reiseprodukt) | active 3, ended 3 |
| `flight` | 4 | Flug | `flight` | `.flight` | ended 4 |
| `package` | 1 | Pauschalreise | `travel` | `.hotel` | ended 1 |
| `car` | 1 | Kfz-Versicherung | `insurance` | verworfen | presale_priced |
| `dsl` | 1 | Internet | `telco` | verworfen | active |
| `gas` | 1 | Gas | `energy` | verworfen | active |
| `un` | 1 | Unfallversicherung | `insurance` | verworfen | ended |
| `mobileservice` | 1 | Handytarif | `mobile_communication` | verworfen | terminated |
| `ferry` | 0 | — | — | `.ferry` (Code) | **nicht in diesem Konto** |

Chips der KB-API (Gruppen mit Buchungen in diesem Konto): `hotel_holidayflat`, `rentalcar`, `flight`, `insurance`, `energy`, `travel`, `telco`, `mobile_communication`. Kein Chip `ferry` / `train` / `activity`.

## Code-Whitelist vs. Live

Quelle: [`ActivityListParser.travelProductKeys`](../../Sources/ReisenCheck24/Parsers/ActivityListParser.swift)

| `product.key` | Mapping heute | Live n | In Unit-Tests |
|---------------|---------------|--------|----------------|
| `hotel` | `.hotel` | 33 | ja |
| `flight` | `.flight` | 4 | ja |
| `ferry` | `.ferry` | 0 | — |
| `holidayflat` | `.hotel` | 6 | — |
| `package` | `.hotel` | 1 | — |
| `rentalcar` | `.carRental` | 9 | ja |

Alles andere wird **still verworfen** (`guard travelProductKeys.contains`).

## Hypothesen (Stand Live 2026-08-28, Browser-Nachprüfung)

| Hypothese | Verdict | Beleg |
|-----------|---------|--------|
| `rentalcar` | **belegt** | 9 Activities, Label Mietwagen, Chip `rentalcar`, Vertical [mietwagen.check24.de](https://mietwagen.check24.de/), Domain `.carRental` |
| `car` / `mobility` | **anders benannt** | `car` = Kfz-Versicherung (`einsurance/kfz`); Mietwagen = `rentalcar` auf `mietwagen.check24.de`; `mobility` nicht gesehen |
| `insurance` | **anders benannt** | kein `product.key` `insurance`; Keys `car` + `un`, Group/Chip `insurance` |
| `train` / `bahn` / `rail` | **kein Buchungsprodukt** | 0 Activities, kein Chip; `www.check24.de/bahn/` liefert KFZ-Inhalt (kein Bahn-Vertical). Domain `.train` bleibt für andere Provider |
| `activity` / `ticket` / `event` | **Vertical ohne Sync-Key** | 0 Activities, kein Chip; Verkaufs-Vertical [erlebnisse.check24.de](https://erlebnisse.check24.de/) existiert. Whitelist erst mit Live-`product.key` einer gebuchten Erlebnis-Activity |
| `ferry` | Code-only | 0 in diesem Konto — Key **nicht** aus der Whitelist streichen |
| `package` eigener Typ | **zurückgestellt** | 1 Activity `package` → Detail `urlaub.check24.de/kundenbereich/detail/:id` zeigt Hotel+Flug (kein `basketDetails`). Katalog bleibt `.hotel`; eigener Typ bräuchte Composite-Enrich |

## Vertical: Mietwagen (`rentalcar` → `.carRental`)

Live-Beleg 2026-08-28: Canonical/Origin **[https://mietwagen.check24.de/](https://mietwagen.check24.de/)** — Titel „Mietwagen Preisvergleich“, Formular „Mietwagen finden“, Footer CHECK24 Mietwagen GmbH. **Nicht** Kfz-Versicherung.

| Rolle | URL / Muster |
|-------|----------------|
| Suche / Vertical | `https://mietwagen.check24.de/` |
| Neu vergleichen (Katalog-Buttons) | `mietwagen.check24.de/ul/jumpin?...` |
| Buchungsdetail (`link.link`) | `mietwagen.check24.de/ul/booking/list/foreign/:id` (Redirect → `/kb/:id`) |
| Kundenportal (nach Redirect) | `mietwagen.check24.de/kb/:id` |
| Voucher | `mietwagen.check24.de/ajax/booking/document/...` |

Abgrenzung: `product.key` `car` (Kfz-Versicherung) zeigt auf `www.check24.de/einsurance/kfz/...`, nicht auf dieses Vertical.

**Code-Stand:** `rentalcar` → `.carRental`. `Check24BookingDetailURL.isCarRentalDetail` erkennt `/ul/booking/` und `/kb/:id`. Catalog-HTML-Enrich und `enrichBooking` nutzen `Check24CarRentalDetailParser` (`CpInitial` + data-qa). Fixture: `docs/fixtures/provider-research/check24_rentalcar_detail_redacted.html`. Gap-Deep-Link: `Check24DeepLinkBuilder` → `/ul/jumpin?dep_destination_name=&dest_destination_name=` (Browser: füllt Abhol-/Rückgabeort; reine IATA-Hints werden übersprungen). Hotel-Enrich-Hosts umfassen `ferienwohnung.check24.de`. HTML-Fallback kennt `mietwagen`.

## Neue Keys: Detail-URL / Enrichment

| Key | Detail-URL-Muster | Katalogfelder | HTML-Enrichment |
|-----|-------------------|---------------|-----------------|
| `rentalcar` | `…/ul/booking/list/foreign/:id` → `/kb/:id` | `startDate`/`endDate`, `payment`, `persons`, `link.link` | `CpInitial` → Operator, Orte, Adressen, Preis, Fahrzeugklasse (`Check24CarRentalDetailParser`) |
| `package` | `urlaub.check24.de/kundenbereich/detail/:id` | wie Hotel-Katalog; Neu-Suche `urlaub.check24.de/suche/angebot?…` | Live-Detail: Hotelaufenthalt + Flugzeiten, **kein** `basketDetails` → bleibt `.hotel`, kein Enrich-Host `urlaub` |
| `holidayflat` | `ferienwohnung.check24.de/kundenbereich/buchung/:uuid` | analog Hotel | bereits `.hotel` |
| `car` / `un` / Energie / Telco | Produkt-Hosts außerhalb Reise | — | skip |

`rentalcar` in diesem Konto durchweg `ended`/`cancelled` — Future-Filter würde sie auch nach Whitelist-Aufnahme verwerfen, bis eine zukünftige Buchung existiert.

## Live-Audit-Checkliste (Acceptance)

1. [x] Eingeloggt Activities-API erfasst (Live-GET, kein Roh-HAR committed).
2. [x] Alle `product.key`-Werte inkl. Häufigkeit tabelliert (auch ausgefilterte).
3. [x] Pro neuem Key: Detail-URL-Muster dokumentiert; Mietwagen-Detail live gelesen und redigiert (Roh-HTML nicht committed).
4. [x] Whitelist + `mapBookingType`: `rentalcar` → `.carRental` (nicht `car`). Kein `train`/`activity`/`ferry`-Bump.
5. [x] Redigierte Fixture unter `docs/fixtures/provider-research/check24_activities_keys_redacted.json` (Live-Keys).
6. [x] Diese Spec: Status → Live-Keys; Tabelle um Live-Häufigkeiten aktualisiert.
7. [x] Redigierte Mietwagen-Detail-Fixture + `Check24CarRentalDetailParser` + Catalog-/Enrich-Anbindung.
8. [x] Browser-Nachprüfung 2026-08-28: `train`/`activity`/`package`-Typ + Mietwagen-Gap-Jumpin.

## Offen (bewusst)

- Whitelist `train`/`activity` erst mit Live-`product.key` einer gebuchten Activity (Erlebnisse-Vertical existiert, Sync-Key fehlt in diesem Konto).
- `package` als eigener Domain-Typ + Enrich auf `urlaub.check24.de` (Composite Flug+Hotel).
