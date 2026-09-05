# App Semantik-Audit Implementation Plan

> Spiegel des freigegebenen Cursor-Plans `app_logic_audit_fix`. Policies: Spec `docs/superpowers/specs/2026-09-05-app-semantics-audit-design.md`.

**Goal:** Fail-visible Prefs/CloudKit/Zeit/Provider-Sync + Shell/SharedUI-Parity; Logging/Tests mitliefern.

**Branch:** `audit/app-semantics-2026-09-05`

## Global Constraints

- Domain-first; keine stillen Fallbacks; `DiagnosticLogger` only
- Commits/Push/PR nur auf Nutzerwunsch
- UI: `macos-ui-test-remote.sh`; iOS: `ios-test.sh`; Gate: `ci-test.sh`
- Prefs-Design 2026-09-04: Fehler ≠ kein Record

## Tasks

### Task W0 — Spec (done with this file + design spec)

- [x] Design-Spec + dieser Plan
- [x] Ledger-Schema in Spec

### Task W1 — Data / AppCore / Domain

- [x] `CloudKitAwaitResult` + Caller-Verträge
- [x] `PrefsImportOutcome`; poison-clear `false` on delete fail
- [x] Mirror: singleton only; dedupe throws
- [x] EventKit skip missing offset; FlightTimeZoneAssigner log/throw
- [x] Deadline replace/retain tests; Epoch-0 gate
- [x] Tests in bestehenden Targets erweitern

### Task W2 — Provider Sync

- [x] Opodo throw on GraphQL/session errors
- [x] Booking timelineFailures > 0 throw
- [x] Check24 FutureRelevant Hotel-Tag-Anker + basket diagnostics
- [x] Opodo hotel offset; Booking deadline diagnostic

### Task W3 — SharedUI

- [x] Gap-Save Persist-Alert + DiagnosticLogger
- [ ] Cancel/PasteImport Semantik angleichen — defer (kein high Drift belegt)
- [ ] XCUI bei UI-Diff — Gap-Save Alert ohne neue Identifier-Journey; Remote-XCUI on demand

### Task W4 — Shell

- [x] Trip/Sync/Persist-Logging Parity (iOS Diagnostics)
- [x] `print` → DiagnosticLogger
- [x] ios-test bei iOS-Diff

### Task W5 — Opt / Residual / Verify

- [x] Overlap Map am Screen-Owner nur mit Evidence — defer (keine Evidence)
- [x] Residual-Scan; Ledger aktualisieren
- [x] `bash ./Scripts/ci-test.sh`; Abschluss-Reviews
