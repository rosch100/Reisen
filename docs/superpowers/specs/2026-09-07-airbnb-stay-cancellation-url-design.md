# Airbnb Stay: Storno-URL (cancellationUrl)

Datum: 2026-09-07
Status: freigegeben (best practice = Experience-Muster)
Plattformen: macOS / iOS (Provider-Extract; UI unverändert)

## Ziel

Airbnb-**Stay**-Buchungen (`.hotel`) bekommen eine belegte, buchungsspezifische `cancellationUrl`, damit der bestehende Storno-Button erscheint — analog Experience.

## Beleg

Live-Cancel-Seite (eingeloggt):

`https://www.airbnb.de/alterations/stays/{confirmationCode}/cancel`

Titel: „Deine Anfrage stornieren“. Flow mit Stornogrund ≠ Trip-Open-URL
(`…/trips/v1/…/ro/RESERVATION/{code}`).

Alter Kandidat `/reservation/cancel/{code}` war 404 und bleibt ungültig.

## Entscheidung

| Thema | Wahl |
| --- | --- |
| Mode | `distinctURL` (wie Airbnb `.activity`) |
| Builder | `AirbnbAPI.stayCancellationURL(confirmationCode:)` |
| Template | `{AirbnbAPI.baseURL}/alterations/stays/{encodedCode}/cancel` |
| Setzt | Catalog (`AirbnbTripsGraphQLParser` Stay-Zweig) |
| Encoding | gleiches Path-Segment-Encoding wie Experience |
| Logging | entbehrlich (reiner URL-Bau; kein neuer I/O-Pfad) |
| UI | keine Änderung (ActionBar/Sheet nutzen `cancellationUrl`) |

## Nicht-Ziele

- In-Page oder `sessionBoundDistinct`
- Opodo/Booking/Check24
- Experience-URL ändern
- HAR ins Repo

## Akzeptanz

1. Stay-Draft mit Confirmation Code → `cancellationUrl` = Stay-Template; ≠ `externalUrl` wenn Open gesetzt.
2. Policy `(.airbnb, .hotel)` = `.distinctURL`.
3. Experience-Regression grün; Encoding-Test für Stay analog Experience.
