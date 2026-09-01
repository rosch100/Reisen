# Provider-Storno-URL-Extract Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans (Tasks gekoppelt) mit TDD.

**Goal:** Jeder Sync-Provider persistiert eine **belegte** Storno-URL gemäß Policy-Mode oder bleibt bewusst `nil`. Kein Raten. Open-URL-Kopie nur bei dokumentiertem `inPageOnOpen` (GYG).

**Architecture:** Bestehendes `cancellationUrl` / `TravelokaAPI.refundPresubmissionURL`-Muster. URL-Bau im Provider-Modul (`*API` / `*Web`). Catalog/Parser setzt Facts. GYG: `cancellationUrl == externalUrl` (In-Page-Modal).

**Beleg Stand 2026-08-30:** Airbnb Experience HAR `app_url` = `/experience_alteration/{code}?flow=oneCancel&productType=experience` (Host `AirbnbAPI.baseURL`). Browser: Seite „Verwalte dein gebuchtes Erlebnis“, nicht 404. Stay `/reservation/cancel/{code}` = 404. Übrige Provider: Cancel-Click-HAR fehlt.

## File map

- Modify: `Sources/ReisenAirbnb/AirbnbAPI.swift` — SSOT Experience-Storno-URL
- Modify: `Sources/ReisenAirbnb/AirbnbTripsGraphQLParser.swift` — `cancellationUrl` bei Experience
- Modify: `Tests/ReisenAirbnbTests/ParserTests.swift`
- Modify: `docs/dev/airbnb-experiences-impl-spec.md`
- Modify: `docs/dev/booking-portal-open.md` (bereits Matrix)
- Modify: Spec-Matrix (bereits)

---

### Task 1: Airbnb Experience-Storno-URL

**Files:** AirbnbAPI, AirbnbTripsGraphQLParser, ParserTests, airbnb-experiences-impl-spec.md

- [ ] **Step 1: Failing test** — `airbnbTripListMapsExperienceToActivity`: `cancellationUrl` = `https://www.airbnb.de/experience_alteration/<REDACTED>?flow=oneCancel&productType=experience` und `!= externalUrl`. Stay-Catalog bleibt `nil` (bestehender Test).
- [ ] **Step 2: Run** `swift test --filter airbnbTripListMapsExperienceToActivity` — RED.
- [ ] **Step 3: Minimal** — `AirbnbAPI.experienceCancellationURL(confirmationCode:)` + Facts `cancellationUrl` nur für Activity.
- [ ] **Step 4: GREEN** + Impl-Spec eine Zeile.
- [ ] **Step 5: Commit**

### Task 2: Übrige Provider

Nur nach neuer HAR/Browser-URL, die ≠ Open-URL ist. Bis dahin nil-Tests unverändert.

---

## HAR-Capture (nicht im Repo)

Safari oder Firefox, eingeloggt, **eine** aktive Buchung:

1. Network aufzeichnen.
2. Zur Buchung, **Storno/Cancel** klicken (nicht nur Detail öffnen).
3. HAR speichern nach `HAR/<provider>_cancel_<datum>.har`.

| Provider | Start | Erfolg |
|----------|--------|--------|
| Check24 | `kundenbereich/buchung/{uuid}` | Request-URL mit storn/cancel ≠ Detail-URL |
| Booking.com | Confirmation | Cancel-URL ≠ confirmation.html |
| Airbnb Stay | Trip-Detail | `app_url`/`url` der Cancel-Row |
| GYG | `/booking/{hash}` | In-Page: Cancel-Modal ohne eigene HTTPS-URL → Mode `inPageOnOpen` (`cancellationUrl == open`) |
| Opodo | `#tripdetails/td=` | Cancel/Refund-Route ≠ tripdetails |
| billiger-mietwagen | `/reservation/account/bookings/{id}` | Storno-URL ≠ Booking-Page |
