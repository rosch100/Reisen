# BM Booking-Scoped Cancel Assist Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** BM Stornieren lands on booking-scoped cancel form via detail-page assist, with booking-page fallback.

**Architecture:** Switch BM to `inPageOnOpen` (`cancellationUrl == externalUrl`). Cancel-Sheet runs one-shot `BilligerMietwagenCancelAssist` after booking-detail load; failure leaves the detail page.

**Tech Stack:** Swift, WKWebView, Swift Testing, DiagnosticLogger

## Global Constraints

- Reisen storniert nicht selbst.
- Keine Buchungs-IDs/PII in Logs.
- Assist nur einmal pro Sheet-Load.
- Tests: `bash ./Scripts/ci-test.sh`. Kein XCUI (keine Identifier-UI-Diff).

---

### Task 1: Policy + Catalog + Assist + Sheets + Docs

**Files:**
- Modify: `ProviderCancellationLinkPolicy.swift`, BM parser/WebConstants, Policy/Parser tests
- Create: `Sources/ReisenProviders/BilligerMietwagenCancelAssist.swift` (+ Script/Runner)
- Modify: macOS + iOS `BookingPortalCancelSheetHost*`
- Modify: portal-links / booking-portal-open / sheet design docs

- [x] **Step 1:** Failing tests (policy inPage; catalog cancel==open; assist script/status parsing)

- [x] **Step 2:** Implement policy, catalog, assist runner, wire `didFinish`

- [x] **Step 3:** Docs matrix + sheet-spec BM-Zeile

- [x] **Step 4:** `bash ./Scripts/ci-test.sh`
