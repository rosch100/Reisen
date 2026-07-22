# API-Recherche: Opodo & Booking.com (Juli 2026)

Zweck: Prüfen, ob offizielle APIs für **private Kontodaten / eigene Buchungen** nutzbar sind.

## Booking.com

| API | Zweck | Für privaten My-Trips-Sync? |
|-----|--------|------------------------------|
| [Demand API](https://developers.booking.com/demand/docs/orders-api/overview) (`/orders/details`) | Partner/Affiliate: Orders aus dem eigenen Vertriebskanal | **Nein** – braucht Affiliate-ID + API-Key; liefert Partner-Buchungen, nicht das Endnutzer-Konto |
| [Data Portability API](https://developers.booking.com/datasecurity/docs/development-guide/api) (DMA) | Nutzer-Export (ZIP) nach App-Registrierung + OAuth | **Nicht ohne Registrierung** – OAuth-Client bei Booking.com nötig; UX = Porting-URL, kein Live-Sync |
| Session My Trips | `GET https://secure.booking.com/mytrips.de.html` mit Browser-Cookies | **Ja** – session-gebunden (wie Check24 Activities-API) |

Fazit Booking.com: Keine frei nutzbare Consumer-JSON-API für „Meine Buchungen“. Primärpfad = cookie-authentifizierter Abruf von My Trips (+ Detail-URLs); HTML-Parser als Fallback.

## Opodo (eDreams ODIGEO)

| API | Zweck | Für privaten Sync? |
|-----|--------|---------------------|
| Partner / Connectivity APIs | B2B Suche/Buchung/Inventar | **Nein** – Partnervertrag |
| Session GraphQL | `POST https://www.opodo.de/frontend-api/service/graphql` (Login/User) | Teilweise – Session prüfen; Buchungsliste in HAR nicht als stabile Query sichtbar |
| Session HTML | `https://www.opodo.de/travel/secure/` / Tripdetails | **Ja** – cookie-authentifiziert |

Fazit Opodo: Keine öffentliche Consumer-API für „Meine Reisen“. Primär: GraphQL-Session-Check + authenticated HTML/JSON-Fetch; Scraping nur Fallback.

## Umsetzung in Reisen

1. Cookie-`URLSession` über `WKWebView` (Shared in `ReisenProviders`)
2. Booking: My Trips per GET; Details per GET der Booking-URL
3. Opodo: GraphQL `GetUserAccount` / `GetUser`; Katalog über authenticated Secure/Trip-HTML
4. Demand-/Partner-APIs bewusst nicht verdrahtet (keine Credentials, falscher Scope)
