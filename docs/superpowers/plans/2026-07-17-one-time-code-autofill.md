# One-Time Code AutoFill Implementation Plan

> **For agentic workers:** Implement task-by-task; steps use checkbox syntax.

**Goal:** Enable Apple Security Code AutoFill for OTP fields in provider WKWebViews.

**Architecture:** URL heuristic in ReisenProviders; JS injection + MutationObserver in Reisen/Platform; wire into Check24 and generic session coordinators.

**Tech Stack:** Swift, WebKit, Swift Testing / XCTest as used in repo.

## Global Constraints

- No SMS/Mail content APIs; only `autocomplete="one-time-code"`.
- No silent fallbacks or dummy codes.
- Match existing `LoginAutofill` / `RememberBrowser` patterns.

---

## Task 1: AuthPageURLHeuristic + Tests

- [x] Add `Sources/ReisenProviders/AuthPageURLHeuristic.swift`
- [x] Add `Tests/ReisenProvidersTests` + Package.swift target
- [x] Cover login vs OTP vs account URLs

## Task 2: OneTimeCodeAutofill

- [x] Add `Sources/Reisen/Platform/OneTimeCodeAutofill.swift`
- [x] JS mark + MutationObserver

## Task 3: Wire into session views

- [x] `Check24SessionView` coordinator
- [x] `GenericProviderSessionView` coordinator

## Task 4: Verify

- [x] `swift test` / build
