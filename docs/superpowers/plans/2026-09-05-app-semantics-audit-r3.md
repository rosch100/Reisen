# App Semantik-Audit R3 Implementation Plan

> Spiegel Spec `docs/superpowers/specs/2026-09-05-app-semantics-audit-r3-design.md`.
> Policies: R1-Design + R2-Ledger; dieser Pass nur Residual-Fixes.

**Goal:** Fail-visible Diagnostics auf verbleibenden stillen Pfaden; iOS Persist-Parity.

**Branch:** `audit/app-semantics-2026-09-05-r3`

## Tasks

### W0 — Spec

- [x] Design-Spec R3 + dieser Plan
- [x] Ledger in Spec

### W1 — Fixes

- [x] GitHubIssueReporter.persist / CrashCatcher.flushPending → DiagnosticLogger; writePending ohne print
- [x] Check24 ActivityListParser: HTML booking drops + Diagnostic
- [x] OffenTab / ReisenTab Persist Diagnostic
- [x] RootTabView PasteImport-Fetch Fail Diagnostic
- [x] Booking.com EnrichFlight soft nil → Diagnostic.skipped
- [x] Tests erweitern

### W2 — Verify / Ship

- [x] `bash ./Scripts/ci-test.sh`
- [x] `bash ./Scripts/ios-test.sh` (iOS-Diff)
- [x] Codereview → Fix medium+
- [ ] PR + Merge
