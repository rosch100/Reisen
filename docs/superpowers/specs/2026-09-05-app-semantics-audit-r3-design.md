# Design: App Semantik-/Logik-Audit R3 (macOS + iOS)

**Datum:** 2026-09-05
**Status:** approved (Nutzer: voller Prozess ohne Rückfragen; Policy-Spiegel freigegeben)
**Scope:** Frischer Residual-Pass nach #154/#155. Policies unverändert; neue Findings fixen.

## Problem

Trotz R1/R2 bleiben stille Diagnose-/Persist-Lücken (DEBUG-`print`, HTML-Booking-`try?`, iOS-Tabs ohne Persist-Diagnostic, Booking soft-enrich ohne Event).

## Ziele

1. Produkt-/Shell-Pfade ohne `print`; Failures über `DiagnosticLogger`
2. Check24 HTML-Link-Parse: Drops zählen + Diagnostic (kein stilles `try?`)
3. iOS Offen/Reisen Persist-Fehler diagnostizieren (Parität TripDetail/BookingDetail)
4. Booking.com Flight-Enrich Soft-Fail → `.skipped` Diagnostic
5. Ledger + Tests im Diff

## Nicht-Ziele

- Wipe-on-Open-Retry, Overlap-Map ohne Evidence
- Cancel/PasteImport Semantik-Angleich
- Airbnb/GYG/Billiger/Traveloka Soft-Enrich umbauen (außer klarer high)
- Crash-Signal-Pfad: kein async Diagnostic in `writePending` (return `false` reicht)
- Token-Einbettung als Finding

## Policies (unverändert)

Siehe `2026-09-05-app-semantics-audit-design.md` (R1) + R2-Ledger. Kurz: Prefs fail-visible, kein `TimeZone.current`-Offset-Fallback, Provider GraphQL-Errors throw, Persist Alert+Diagnostic.

## Finding-Ledger (R3)

| id | severity | area | status | notes |
| --- | --- | --- | --- | --- |
| R3-print-github-persist | medium | AppCore | fix | Reporter.persist → DiagnosticLogger |
| R3-print-crash-flush | medium | AppCore | fix | flushPending catch → DiagnosticLogger |
| R3-print-crash-write | low | AppCore | fix | writePending: print entfernen; return false |
| R3-check24-html-tryq | medium | Check24 | fix | Booking-Window-Drops + Diagnostic |
| R3-ios-offen-persist | medium | Shell | fix | OffenTab delete Diagnostic |
| R3-ios-reisen-persist | medium | Shell | fix | ReisenTab delete Diagnostic |
| R3-ios-root-fetch | low | Shell | fix | RootTabView fetch-Fail Diagnostic |
| R3-booking-enrich-soft | medium | Booking | fix | Order/Parse nil → skipped Diagnostic |
| R3-verify-r1-r2 | — | — | ok | Prefs/Mirror/Opodo/EventKit/TZ/Basket OK |
| defer-wipe-open | — | Data | defer | |
| defer-cancel-paste | — | SharedUI | defer | |
| defer-overlap | — | UI | defer | |
| defer-traveloka-soft | — | Traveloka | defer | |
| defer-airbnb-iana | — | Airbnb | defer | |

## DoD

Root Cause, Policy, Diagnostics, Semantik-Test, `ci-test.sh`, iOS-Diff → `ios-test.sh`, Codereview medium+ clean, PR merge.
