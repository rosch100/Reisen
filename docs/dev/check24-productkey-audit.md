# Check24 productKey-Audit

Status: **Teilweise** — bekannte Keys aus Code/Tests + Fixture erfasst; **vollständige Live-API-Liste fehlt** (keine Check24-HAR im Repo).

Siehe Überblick: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § Check24.  
Fixture: [`../fixtures/provider-research/check24_activities_keys_redacted.json`](../fixtures/provider-research/check24_activities_keys_redacted.json).

## Erfasst (Code-SSOT)

Quelle: [`ActivityListParser.travelProductKeys`](../../Sources/ReisenCheck24/Parsers/ActivityListParser.swift)

| `product.key` | Mapping heute | In Unit-Tests gesehen |
|---------------|---------------|------------------------|
| `hotel` | `.hotel` | ja |
| `flight` | `.flight` | (Parser-Pfad) |
| `ferry` | `.ferry` | — |
| `holidayflat` | `.hotel` | — |
| `package` | `.hotel` | — |

Alles andere wird **still verworfen** (`guard travelProductKeys.contains`).

## Nicht erfasst (Blocker)

Ohne HAR/Live-Antwort von `…/kb/api/activities` können weitere Keys **nicht** belegt werden. Im Repo liegt keine Check24-HAR.

### Hypothesen (unverified — nicht implementieren)

| Mutmaßlicher Key | Möglicher `BookingType` | Hinweis |
|------------------|-------------------------|---------|
| `rentalcar` / `car` / `mobility` | neu oder `.other` | Mietwagen |
| `train` / `bahn` / `rail` | neu oder `.other` | Bahn |
| `activity` / `ticket` / `event` | `.activity` | Erlebnisse |
| `insurance` | skip | Ancillary |

## Live-Audit-Checkliste (Acceptance)

1. [ ] Eingeloggt HAR mit Activities-API speichern (nicht committen roh).
2. [ ] Alle `product.key`-Werte inkl. Häufigkeit tabellieren (auch ausgefilterte).
3. [ ] Pro neuem Key: Detail-URL/Enrichment-Machbarkeit prüfen.
4. [ ] Whitelist + `mapBookingType` nur für belegte Keys erweitern.
5. [x] Redigierte Fixture unter `docs/fixtures/provider-research/check24_activities_keys_redacted.json` (Code-known Keys).
6. [ ] Diese Spec: Status → „vollständig“, Tabelle um Live-Keys aktualisieren.

## Bis dahin

Keine Whitelist-Änderung im Produktivcode ohne Live-Beleg.
