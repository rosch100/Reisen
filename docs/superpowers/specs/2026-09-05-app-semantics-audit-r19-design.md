# Design: App Semantik-Audit R19

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R18

## Problem

R17 machte ListInclusion typbewusst (`listInclusionCalendar`). R18 trennte in
`OpenBookingMatching.isCandidate` Fenster (GMT) von Upcoming (typbewusst).
`TripBookingAssignment.assignableBookingIDs` nutzte weiter **einen** `calendar`
(Default `HotelStayDate.calendar`) für beides — Flüge „ab heute“ fälschlich unter GMT.

## Fixes

| id | sev | status | notes |
| --- | --- | --- | --- |
| r19-assign-upcoming-vs-listinclusion | medium | fix | Upcoming → `listInclusionCalendar`; Fenster → `HotelStayDate.calendar`; API `upcomingCalendar` / `windowCalendar` |

## Ansatz

1. `assignableBookingIDs` / `bookingIDsToAssign` / `assignableCount`: getrennte Parameter.
2. `upcomingCalendar: Calendar? = nil` → je Buchung `bookingType.listInclusionCalendar`.
3. `windowCalendar: Calendar = HotelStayDate.calendar` (R18 SSOT; Override nur Tests).
4. `OpenBookingMatching`-Kommentar an die getrennte Assignment-API anbinden.

## Wontfix / Defer (unverändert)

| id | reason |
| --- | --- |
| r14-booking-html-cancel | braucht HAR |
| Opodo epoch nil offset / wall-clock 0 | R9/R1/R8 |
| Traveloka soft-401 / Check24 soft-snapshot | Soft-Enrich/Catalog |
| Token-Embed | Exclusion |

## DoD

Tests (Hotel-GMT grün + Flug East-of-GMT), Spec/Plan, kein Commit in diesem Schritt.
