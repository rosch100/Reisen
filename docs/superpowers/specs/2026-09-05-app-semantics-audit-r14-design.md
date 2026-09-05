# Design: App Semantik-Audit R14

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R12 (#154–#166); R13 CLEAN-Probe; frische Analyse R14

## Problem

`resolveTripIDs` filtert canceled Trips in GetTrips (`parseTripIDs`), startet die Ordnung aber mit unverändertem `preferredTripIDs` (HTML). Canceled Trips, die GetTrips weglässt, können so wieder in den Katalog gelangen.

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r14-booking-preferred-cancel-filter | high | fix | Pure `BookingComTripIDOrdering.mergePreferredTripIDs`; GetTrips non-empty → preferred ∩ active (preferred order), dann Rest GetTrips; GetTrips empty → Fallback `preferredTripIDs` |

## Wontfix / Defer

| id | reason |
| --- | --- |
| Opodo epoch `freeCancellationLimit` nil offset | R9 absichtlich Absolute Instant (kein erfundenes `0`); nicht droppen |
| Traveloka refund soft-401 | Soft-Enrich |
| Check24 catalog soft-snapshot | Soft-snapshot |
| Booking/Opodo GraphQL invalidJSON detail | niedriger Nutzen |
| Opodo Wall-Clock offset `0` | R1/R8 Konvention |
| iOS remove-from-trip | UX Scope |
| unsupported enrich empty | default |
| r14-booking-html-cancel | **defer** — siehe unten |

## Defer detail: `r14-booking-html-cancel`

**Risk (belegt im Code):** HTML-Katalog-Fallback
(`Catalog` → `fetchCatalogFallbackHTML` → `BookingComActivityListParser`) baut
Drafts über `draft(url:startAt:endAt:)` **ohne** `statusRaw`
(`BookingComActivityListParser+Helpers`). `BookingStatus.parse(nil)` → `.unknown`;
`CatalogListing.shouldDrop(nil)` ist false → Storno-Links aus dem DOM können bei
GraphQL-Fail wieder als aktive Drafts landen.

**Warum kein HIGH/MEDIUM-Fix ohne Heuristik:**

| Kandidat | Evidenz |
| --- | --- |
| URL-Marker / Cancel-Query | keine in Repo-Fixtures; My-Trips-HTML-Test nur `trip_id=` (HAR-Regression Marketing-Copy) |
| HTML-Cancel-Class / Badge | keine My-Trips-SSR-Fixture mit Storno-Card; Confirm-`e2e-cancellation-*` = Fee-Policy, nicht Trip-Status |
| Substring `cancel`/`storniert` im Link-Window | kollidiert mit Free-Cancellation-Copy (`hotel_confirmation_sample.html`, `BookingStatus.parse` Freetext) |
| Booking.com My-Trips HAR | nicht im Tree (`HAR/` hat kein Booking.com-Capture; SSOT: GraphQL `trip.canceled`) |

Zuverlässiges Cancel-Signal bleibt GraphQL (`GetTrips`/`timeline.trip.canceled` —
abgedeckt durch `r14-booking-preferred-cancel-filter`). HTML-Fallback erst
fixbar nach Live-/HAR-Capture einer stornierten My-Trips-Card (stabile Klasse,
JSON-Feld oder URL) — nicht per erfundener Substring-Heuristik.

## DoD

Tests, ci-test, codereview, PR, Merge. Danach R15-Analyse; Loop stoppt bei CLEAN.
