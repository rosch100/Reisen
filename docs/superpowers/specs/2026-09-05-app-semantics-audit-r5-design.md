# Design: App Semantik-/Logik-Audit R5 (macOS + iOS)

**Datum:** 2026-09-05
**Status:** approved (Nutzer: voller Prozess ohne Rückfragen)
**Scope:** Residual nach #154–#157. Policies unverändert.

## Problem

R1–R4 haben AppCore/Provider/macOS-Chrome weitgehend fail-visible gemacht. Residual in SharedUI: Persist-Fehler nur UI-Alert ohne `DiagnosticLogger`; Check24 `hotelInfo`-Decode-Fail still `nil`.

## Ziele

1. SharedUI Persist-Fails (PasteImport Review, AssignBookings, TripEditor, BookingEditor Save) → Diagnostic
2. Check24 HotelInfo Decode-Fail → `.skipped` Diagnostic (weiter soft `nil`)
3. Spec/Plan/Ledger + Tests

## Nicht-Ziele

- Soft-Enrich hard throw (Traveloka/Airbnb/Check24 hotelInfo missing)
- Wipe-on-Open, Overlap, Cancel/Paste Semantik-Angleich
- CLI SyncIOSQuerySchemes `print`
- BookingEditor ValidationError als Persist-Fail loggen

## Finding-Ledger (R5)

| id | severity | area | status | notes |
| --- | --- | --- | --- | --- |
| R5-sharedui-persist-helper | medium | SharedUI | fix | SharedUIPersistDiagnostics SSOT |
| R5-pasteimport-persist | medium | SharedUI | fix | PasteImportReview catch → Diagnostic |
| R5-assign-persist | medium | SharedUI | fix | AssignBookingsSheet catch → Diagnostic |
| R5-tripeditor-persist | medium | SharedUI | fix | TripEditorSheet catch → Diagnostic |
| R5-bookingeditor-persist | medium | SharedUI | fix | non-validation Save-Fail → Diagnostic |
| R5-check24-hotelinfo-decode | medium | Check24 | fix | decode catch → skipped Diagnostic |
| R5-verify-prior | — | — | ok | R1–R4 Kern OK |
| wontfix-cli-print | low | Tool | wontfix | |
| defer-wipe-open | — | Data | defer | |
| defer-cancel-paste | — | SharedUI | defer | |
| defer-overlap | — | UI | defer | |

## DoD

Diagnostics + Tests, `ci-test.sh`, UI-Diff → remote XCUI wenn Identifier/UI-Verhalten; hier nur Diagnostics an bestehenden Alerts → kein XCUI-Zwang. Codereview medium+ clean, PR merge.
