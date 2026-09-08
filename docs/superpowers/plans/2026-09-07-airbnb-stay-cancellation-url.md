# Airbnb Stay Cancellation URL Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist Airbnb Stay `cancellationUrl` from confirmation code so the existing cancel control appears.

**Architecture:** Mirror Experience: `AirbnbAPI.stayCancellationURL` + TripList Stay facts + Policy `distinctURL` for `(.airbnb, .hotel)`. No UI/persistence schema changes.

**Tech Stack:** Swift, Swift Testing, ReisenAirbnb / ReisenDomain

## Global Constraints

- Belegpflicht: nur Live-Template `/alterations/stays/{code}/cancel` (kein Raten).
- Host SSOT: `AirbnbAPI.baseURL`.
- Sync: `nil` wischt persistierte Cancel-URL nicht; nicht-leere Draft-URL backfüllt.
- Logging: URL-Bau pure → kein neues DiagnosticEvent.
- Tests: Swift Testing; `bash ./Scripts/ci-test.sh`. Kein XCUI (keine UI-Diff).

---

### Task 1: API + Policy + Catalog + Docs

**Files:**
- Modify: `Sources/ReisenAirbnb/AirbnbAPI.swift`
- Modify: `Sources/ReisenAirbnb/AirbnbTripsGraphQLParser.swift` (Stay-Zweig)
- Modify: `Sources/ReisenDomain/Services/ProviderCancellationLinkPolicy.swift`
- Modify: `Tests/ReisenAirbnbTests/ParserTests.swift`
- Modify: `Tests/ReisenDomainTests/ProviderCancellationLinkPolicyTests.swift`
- Modify: `docs/superpowers/specs/2026-08-31-provider-cancellation-links-all-design.md` (Matrix-Zeile Stay)
- Modify: `docs/dev/booking-portal-open.md` wenn Airbnb Stay erwähnt

**Interfaces:**
- Produces: `AirbnbAPI.stayCancellationURL(confirmationCode: String) -> String`

- [x] **Step 1: Failing tests** — Stay URL encoding; TripList Stay setzt Cancel-URL; Policy hotel = `distinctURL`; Matrix-Coverage-Test.

- [x] **Step 2: Implement** — Builder, Catalog `cancellationUrl`, Policy case `(.airbnb, .hotel)`.

- [x] **Step 3: Docs** — Matrix Stay → distinct + Belegpfad.

- [x] **Step 4: Verify** — `bash ./Scripts/ci-test.sh`
