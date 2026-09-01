# F13 Trip-Kostensumme & Währung — Design

Datum: 2026-09-01  
Status: Promote-and-Gapfill (Backlog F13 + bestehende macOS-Teilsumme + User-Intent Währung); P1-Judge-Korrekturen  
Backlog: [feature-backlog.md](../../dev/feature-backlog.md) F13  

## Ziel

Die Reiseübersicht zeigt eine **ehrliche** Kostensumme: vorhandene Buchungs- und Gap-Preise, **fehlende Preise explizit**, **keine stillen Währungsmischungen**. Optional kann der Nutzer Beträge in eine **bevorzugte Währung** umrechnen lassen (ECB-Referenzkurse über Frankfurter). Kein Budget-Tracker, keine Splits.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---|---|
| **Preiszeile** (`TripCostLine`) | Betrag **und** nicht-leerer ISO-4217-Code. Quelle: Buchung (`BookingRateDetails.totalPriceAmount` + `totalPriceCurrency`) oder Gap (`priceAmount` + `priceCurrencyCode`). Fehlt Betrag **oder** Code (nil/leer/whitespace) → **keine** Zeile, Item zählt zu **fehlend**. |
| **Kostensumme** (`TripCostSummary`) | Pro Währung eine Summe der Preiszeilen + `pricedCount` + `missingCount`. Nie Beträge unterschiedlicher Codes addieren. |
| **Nebeneinander-Anzeige** | Formatierte Teilsammen pro Währung (z. B. `1.234,56 € · $890,00`), sortiert nach Code. |
| **Bevorzugte Währung** | ISO-4217 aus Einstellung; Default = `Locale.current.currency?.identifier`, sonst `"EUR"`. Persistiert unter `AppSettingsKeys.preferredCurrencyCode`. |
| **Umrechnen** | Toggle `AppSettingsKeys.convertAmountsToPreferredCurrency` (Default **aus**). Wenn an: zusätzlich zur Nebeneinander-Anzeige eine umgerechnete Gesamtsumme in der bevorzugten Währung + Referenzkurs-Datum; bei Fehler kein Fake-Total, Nebeneinander bleibt. |
| **Referenzkurs** | Täglicher Zentralbank-Referenzkurs via Frankfurter (`api.frankfurter.dev`), Upstream ECB. Kein Handelskurs, kein Angebot. |
| **Kurs-Satz** (`ExchangeRateQuote`) | `base: String`, `date: Date` (Kalendertag der Quote), `rates: [String: Decimal]` (ISO → Kurs relativ zu `base`). Fehlt ein benötigter Kurs → Umrechnung **fehlgeschlagen**, kein Partial-Summen-Fake. |
| **fehlend** | Timeline-Item (Buchung/Gap) ohne verwertbares Betrag+Code-Paar. UI: z. B. „2 ohne Preis“. |
| **Preiszeilen-Mapper** | ReisenData baut `[TripCostLine]` + `missingCount` aus `SDBooking`/`SDGap` der Timeline. SharedUI formatiert nur. |

**Explizit verworfen:** Stilles Addieren gemischter Währungen. Manuelle Kurs-Eingabe. Historischer Kurs zum Buchungstag (v1 = latest + Datumsstempel). FX-Anbieter mit API-Key. Trading/Wallet. Dummy `0` für fehlende Preise. FX ohne Opt-in.

## Anforderungen

### In Scope (v1)

1. Domain-SSOT `TripCostSummary` aus Preiszeilen.
2. ReisenData-Mapper Timeline → Preiszeilen (Paar-Pflicht).
3. Default-UI (macOS + iOS Übersicht): Nebeneinander + fehlende Preise; keine Preiszeile → „k. A.“ (+ Missing falls > 0).
4. Settings-Section **Währung** (Copy unten); Toggle Default aus; bevorzugte Währung als **Picker** (keine Freitext-ISO), nur sichtbar wenn Umrechnen an (progressive disclosure).
5. Convert an: Fetch/Cache; Preferred-Total (primär) + Original-Nebeneinander + Datumshinweis (sekundär); Fehler → Conversion-unavailable, Original bleibt.
6. Cache TTL ≤ 24 h oder bis Frankfurter-`date` wechselt; Offline mit gültigem Cache ok.
7. Privacy: Settings-Footer **und** Absatz in `docs/legal/privacy.html` + `docs/legal/en/privacy.html`. PrivacyInfo.xcprivacy unverändert.
8. `tripTotalPriceText` in macOS ersetzen.

### Nicht in Scope

- Budget/Expenses/Splits.
- Automatische Umrechnung ohne Opt-in.
- Historische Kurse pro Buchungsdatum.
- Self-host Frankfurter.
- Umrechnung einzelner Buchungszeilen in der Detailansicht.
- Live-corpus gegen api.frankfurter.dev in CI.

## Copy (HIG)

| Key-Rolle | DE | EN |
|---|---|---|
| Section | Währung | Currency |
| Preferred | Bevorzugte Währung | Preferred Currency |
| Toggle | In bevorzugte Währung umrechnen | Convert to Preferred Currency |
| Footer | Bei aktivierter Option werden Summen mit Referenzkursen der Europäischen Zentralbank (über Frankfurter) umgerechnet. Die Werte sind unverbindlich und kein Wechselkursangebot. Dafür wird eine Netzwerkanfrage gestellt. | When enabled, totals use European Central Bank reference rates (via Frankfurter). Values are indicative, not a trading quote. This uses a network request. |
| Missing | %lld ohne Preis | %lld missing price(s) |
| Converted hint | Referenzkurs %@: … | Reference rate %@: … |
| Convert failed | Umrechnung nicht möglich | Conversion unavailable |

## Architektur

| Schicht | Verantwortung |
|---|---|
| **ReisenDomain** | `TripCostLine`, `TripCostSummary`, `ExchangeRateQuote` (`Decimal` rates), `ExchangeRateProviding`, Conversion, `AppSettingsKeys` Currency. Kein URLSession, kein SwiftData. |
| **ReisenData** | Mapper SD Timeline → Preiszeilen + missingCount. |
| **ReisenAppCore** | `FrankfurterExchangeRateClient` + Cache; JSON Double→Decimal an Boundary. |
| **ReisenSharedUI** | Settings-Section; Display-Text; kein Summen-/SD-Mapping. |
| **Reisen / ReiseniOS** | Übersicht verdrahten; Rate-Client nur bei Toggle an. |

## Schnittstellen

| id | kind | supply | evidence |
|---|---|---|---|
| trip-cost-contract | contract | `TripCostSummary` | `TripCostSummaryTests` |
| trip-cost-line-mapper | neighbor | ReisenData Mapper SD→Lines | Data-Tests: Amount-ohne-Code / Code-ohne-Amount → missing |
| exchange-rate-port | contract | Port + Conversion (`Decimal`) | `TripCostConversionTests` Fake-Quote |
| frankfurter-adapter | adapter | Frankfurter Client + Cache | AppCore URLProtocol-Tests |
| currency-settings-entry | entry | Settings Toggle/Field → Keys → Overview liest Keys | Test: UserDefaults nach Settings-Schreibpfad + Display-Input aus denselben Keys (kein reiner Diff) |
| network-capability | capability | Toggle-Default aus; Footer + Privacy-HTML Disclaimer | Assert Default false; L10n-Footer; Privacy-HTML enthält Frankfurter/ECB |
| trip-overview-neighbor | neighbor | macOS + iOS Overview | Format-Tests + Verdrahtung |

## Fehler & No-Fallbacks

- Gemischte Codes: nie eine Zahl.
- Convert an + Kurs fehlt: Fehlertext, Nebeneinander bleibt.
- Convert aus: kein Netzwerk.
- Unpaired amount/currency: missing, nicht still mit `.first` Currency.

## open_gaps

- Live-Frankfurter in CI — Fake-HTTP.
- Historischer Kurs — Folgespec.

## Akzeptanz

1. EUR+USD → zwei Beträge, keine Mischsumme.
2. Amount ohne Code / Code ohne Amount → Missing.
3. Toggle aus → keine FX-Request.
4. Toggle an + Kurse → Preferred-Total **und** Original-Nebeneinander + Datum.
5. Toggle an + Fehler → „Umrechnung nicht möglich“, Original bleibt.
6. Privacy-HTML erwähnt optionale Kursabfrage.
