# Booking.com Hotel: Storno-URL (`cancel*.html` + `auth_key`)

Datum: 2026-09-07
Status: freigegeben (Live cancel.de.html)
Plattformen: macOS / iOS

## Ziel

Booking.com-**Hotel**-Buchungen bekommen eine belegte `cancellationUrl` auf die Storno-Seite.

## Beleg

Live: `https://secure.booking.com/cancel.de.html?…&auth_key=…`  
Titel „Buchung stornieren“, Stornogrund-Schritt — buchungsspezifisch über `auth_key`.

Catalog-Open: `/confirmation.de.html?auth_key=…` (Fixture + GraphQL).  
Transformation: Dateiname `confirmation` → `cancel`, Query inkl. `auth_key` behalten.

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Mode | `distinctURL` nur `.hotel` |
| Builder | `BookingComCancellationURL.fromConfirmationURL` |
| Setzt | GraphQL Draft-Mapper bei `.hotel` |
| Flug/andere | weiterhin `none` / keine Cancel-URL (kein Live-Beleg) |
| Assist | nein |

## Nicht-Ziele

- Auto-Klick „Weiter“ / finale Storno-Bestätigung
- Cancel-URL ohne `auth_key` raten
- Flight-Cancel-Pfad ohne Beleg

## Akzeptanz

1. Hotel-Draft mit Confirmation+`auth_key` → Cancel-URL mit `cancel` + gleichem `auth_key`, ≠ Open.
2. Ohne `auth_key` / ohne Confirmation-Pfad → `nil`.
3. Policy `(.booking, .hotel)` = `distinctURL`.
