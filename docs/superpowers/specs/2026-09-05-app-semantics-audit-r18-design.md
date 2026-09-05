# Design: App Semantik-Audit R18

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R17 (#154–#170)

## Problem

R17/Follow-up machte `OpenBookingMatching` ListInclusion typbewusst (`listInclusionCalendar`).
`isCandidate` übergab denselben Kalender an `TripBookingDateWindow` — Trip-Start/Ende sind
GMT-Anker (`HotelStayDate.calendar`). West-of-GMT: Flüge am letzten Reisetag fälschlich
außerhalb des Fensters; Fill vs. `TripBookingAssignment` divergieren.

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r18-iscandidate-trip-window-gmt | medium | fix | `isCandidate` → `TripBookingDateWindow` immer `HotelStayDate.calendar`; ListInclusion bleibt typbewusst |

## Wontfix / Defer (unverändert)

| id | reason |
| --- | --- |
| r14-booking-html-cancel | braucht HAR |
| Opodo epoch nil offset / wall-clock 0 | R9/R1/R8 |
| Traveloka soft-401 / Check24 soft-snapshot | Soft-Enrich/Catalog |
| Token-Embed | Exclusion |

## DoD

Tests, ci-test, codereview, PR, Merge. Danach R19 CLEAN-Probe.
