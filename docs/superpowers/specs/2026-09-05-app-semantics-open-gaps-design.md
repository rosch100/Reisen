# Design: App-Semantik offene Deferrals schließen

**Datum:** 2026-09-05
**Status:** approved (Nutzer: alle offenen Probleme beheben)
**Scope:** Verbliebene Audit-Deferrals — beheben was Code-Bug ist; Design/Platform als `wontfix` schließen.

## Fixes

| id | status | notes |
| --- | --- | --- |
| defer-opodo-no-tdtoken | fix | missing tdToken → Diagnostic.skipped |
| defer-airbnb-iana | fix | Catalog IANA via AirbnbListingTimeZone + Skip-Diag; Cancel-Jahr ohne referenceDate → nil |
| defer-diag-encode | fix | Encode-Fail schreibt SyncLog-Fallback-Zeile |

## Closed wontfix (kein Bug / bewusste Grenze)

| id | reason |
| --- | --- |
| defer-wipe-open | Wipe+einmal Retry existiert; Erweiterung ohne Evidence = Spekulation |
| defer-macos-push | Plattform/Signing (`apple-signing.md`) |
| defer-boardtype-unknown | bewusstes Domain-Enum |
| W3-cancel-paste | kein HIGH/MEDIUM-Drift (SSOT + Spec-Drops) |
| W5-overlap | keine Main-Thread-Evidence |
| W3-gap-xcui | PersistFailureAlert reused |
| defer-traveloka-hard | Soft-Enrich by design; Skip-Diag seit R4 |
| Prefs/Keychain Live open_gaps | manuelle Acceptance, nicht CI |
| PasteImport Feld-Drops | spezifiziert intentional |
| CLI SyncIOSQuerySchemes print | Tool-Stdout |
