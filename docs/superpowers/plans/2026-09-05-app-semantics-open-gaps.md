# Plan: App-Semantik offene Deferrals

**Spec:** `docs/superpowers/specs/2026-09-05-app-semantics-open-gaps-design.md`
**Datum:** 2026-09-05

## Steps

1. Opodo: missing `tdToken` → `enrich_skipped` / `missing_td_token` (+ Diagnostics-Dep)
2. Airbnb: Catalog IANA via `AirbnbListingTimeZone` + Skip-Diag; Cancel-Jahr ohne `referenceDate` → nil
3. Diagnostics: Encode-Fail → SyncLog-Fallbackzeile
4. Tests: Airbnb Cancel/IANA; Opodo Token-Gate
5. Ledger aktualisieren; `ci-test.sh`; `/codereview`; PR; Merge
