# Design: App Semantik-Audit R15

**Datum:** 2026-09-05
**Status:** approved (Nutzer: Prozess ohne Rückfragen)
**Vorgänger:** R1–R14

## Problem

`HotelStayDate` speichert Kalendertage als GMT-Mitternacht-Anker. Editoren binden `DatePicker` direkt an diese `Date`s und speichern mit `HotelStayDate.dateOnly(fromLocalPickerDate:)`, das Y/M/D über `Calendar.current` liest. West of GMT verschiebt Open→Save ohne Edit den Kalendertag um einen Tag zurück.

## Fix

| id | sev | status | notes |
| --- | --- | --- | --- |
| r15-editor-gmt-anchor-datepicker-load | medium | fix | `localPickerDate(fromStored:)` + TripEditor/BookingEditor hotel load + `createDefault` Prefill |

## Ansatz

1. Inverse API: `HotelStayDatePicker.localPickerDate(fromStored:calendar:)` — Y/M/D aus `HotelStayDate.calendar`, dann lokal via `calendar.date(from:)`. Forwarding über `HotelStayDateStored` / `HotelStayDate`.
2. `TripEditorSheet`: Trip- und Seed-Daten (GMT-Anker aus Persistenz bzw. `TripDateBounds`) beim Load konvertieren.
3. `BookingEditorDraft.fromDomain`: nur `.hotel` (Save-Pfad nutzt `fromLocalPickerDate`); Flights/Cars unverändert.
4. `BookingEditorDraft.createDefault`: Trip-/Gap-Prefill über `localPickerDate`; `now` als `Calendar.current.startOfDay`.
5. Tests: Round-Trip LA/Berlin + West-of-GMT No-Shift + createDefault Prefill.

## DoD

Tests, Spec/Plan, kein Commit in diesem Schritt (Parent orchestriert Ship).
