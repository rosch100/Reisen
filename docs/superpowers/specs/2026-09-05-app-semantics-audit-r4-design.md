# Design: App Semantik-/Logik-Audit R4 (macOS + iOS)

**Datum:** 2026-09-05
**Status:** approved (Nutzer: voller Prozess ohne Rückfragen)
**Scope:** Frischer Residual-Pass nach #154–#156. Policies unverändert.

## Problem

R1–R3 haben Kernverträge geschlossen. Residual: macOS Shell Single-Persist ohne Diagnostic (Batch hat es), ContentView Single-Delete ohne Log, Airbnb ungültige IANA ohne Skip-Event, Traveloka Soft-Refund nur onProgress ohne Diagnostic.

## Ziele

1. macOS TripDetail/ContentView Persist-Fehler → `DiagnosticLogger` (Parität iOS/Batch)
2. Airbnb: ungültige `listingTimeZone` → `.skipped` Diagnostic (Offset bleibt nil)
3. Traveloka Soft-Refund-Fails → `.skipped` Diagnostic (weiter soft, kein Throw)
4. Spec/Plan/Ledger + Tests

## Nicht-Ziele

- Traveloka Soft-Refund → hard throw
- Wipe-on-Open, Overlap-Map, Cancel/Paste Semantik
- SyncIOSQuerySchemes CLI-`print` (Tool-Stdout, wontfix)
- Check24 HotelInfo Soft-nil (kein Sync-Status-grün-ohne-Hinweis)

## Finding-Ledger (R4)

| id | severity | area | status | notes |
| --- | --- | --- | --- | --- |
| R4-macos-trip-persist | medium | Shell | fix | TripDetail single delete/remove/create Diagnostic |
| R4-macos-content-persist | medium | Shell | fix | ContentView trip/open delete + detail Diagnostic |
| R4-airbnb-iana-diag | medium | Airbnb | fix | invalid IANA → skipped Diagnostic |
| R4-traveloka-refund-diag | medium | Traveloka | fix | soft refund fails → skipped Diagnostic |
| R4-verify-prior | — | — | ok | Prefs/Mirror/Opodo/EventKit/Check24/R3 OK |
| wontfix-cli-print | low | Tool | wontfix | SyncIOSQuerySchemes stdout |
| defer-wipe-open | — | Data | defer | |
| defer-cancel-paste | — | SharedUI | defer | |
| defer-overlap | — | UI | defer | |
| defer-traveloka-hard | — | Traveloka | defer | soft enrich bleibt |

## DoD

Diagnostics + Tests, `ci-test.sh`, iOS nur bei iOS-Diff (kein iOS-Diff → skip), Codereview medium+ clean, PR merge.
