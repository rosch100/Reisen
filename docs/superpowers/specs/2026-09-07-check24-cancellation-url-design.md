# Check24: Storno-URL (`?action=cancel`)

Datum: 2026-09-07
Status: freigegeben (Live Hotel-Kundenbereich)
Plattformen: macOS / iOS

## Ziel

Check24-Buchungen bekommen eine belegte, buchungsspezifische `cancellationUrl`, damit der Storno-Button die Storno-Seite öffnet.

## Beleg

Live: `https://hotel.check24.de/kundenbereich/buchung/{uuid}?action=cancel`

Seite zeigt Überschrift „Stornierung“, Frist und Button „Buchung kostenlos stornieren“ — ≠ Open-URL ohne Query. Referrer Kundenbereich (Session üblich).

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Mode | `distinctURL` |
| Builder | `Check24CancellationURL.fromBookingDetailURL` → `{detail}?action=cancel` |
| Setzt | `Check24TravelProvider.mapDraft` bei `kundenbereich/buchung`-URL |
| Assist | nein (URL reicht) |
| Typen | alle mit gleicher Detail-URL-Form (Hotel/Flug/Fähre) |

## Nicht-Ziele

- Auto-Klick auf „Buchung kostenlos stornieren“
- Booking.com in derselben Änderung

## Akzeptanz

1. Draft mit Detail-URL → `cancellationUrl` endet auf `?action=cancel`, ≠ `externalUrl`.
2. Policy Check24 = `distinctURL`.
3. Unit-Tests + Docs-Matrix.
