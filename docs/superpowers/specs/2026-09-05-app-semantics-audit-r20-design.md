# Design: App Semantik-Audit R20 (CLEAN)

**Datum:** 2026-09-05
**Status:** CLEAN — Loop gestoppt
**Vorgänger:** R1–R19 (#154–#172); frische parallele Analysen ohne medium+/high

## Verdict

Zwei unabhängige R20-Proben: **CLEAN**. Keine neuen medium+/high Findings.

## Abgedeckt (R14–R19, zuletzt gemerged)

| Pass | PR | Fokus |
| --- | --- | --- |
| R14 | #167 | Booking preferred ∩ GetTrips aktiv |
| R15 | #168 | DatePicker GMT-Anker Load |
| R16 | #169 | Expand/Preview/EventKit/Trip-Elapsed |
| R17 | #170 | Hotel-ListInclusion + birthDate civilDay + Offen typbewusst |
| R18 | #171 | isCandidate Trip-Fenster immer GMT |
| R19 | #172 | Assignment Upcoming typbewusst / Fenster GMT |

## Bewusst offen (Defer/Wontfix, kein medium+-Fix ohne Evidenz)

- Booking HTML-Cancel ohne `statusRaw` (HAR nötig)
- Opodo epoch `freeCancellationLimit` nil Offset; Wall-Clock `0`
- Traveloka soft-401 Refund; Check24 soft catalog snapshot
- Token-Embed in Releases (Exclusion)
- SyncBookingMatchIndex „ab heute“ weiter GMT (R17 explizit unverändert)

## DoD

Keine Produktänderung in R20. Stop-Kriterium erfüllt.
