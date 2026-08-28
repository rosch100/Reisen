# HAR Discovery (Opodo, Booking.com) - temporär

Siehe auch: [`API_Research_Opodo_Booking.md`](API_Research_Opodo_Booking.md) (öffentliche Partner-APIs vs. session-gebundene Abrufe).

Zweck: Aus den vorhandenen HAR-Captures die wahrscheinlich nutzbaren Login-/Account- und Daten-Endpunkte herausziehen, um anschließend Parser/Provider-Implementierungen zu bauen.

Wichtige Regel: HAR ist nur temporäre Referenz. Nach Stabilisierung sollen HAR-Dateien bereinigt/entfernt werden und Parser sollen primär aus session-gebundenen APIs bzw. HTML-Fallbacks funktionieren.

## Opodo (www.opodo.de) - relevante Anker

Gefundene Endpunkte aus HAR:

- `https://www.opodo.de/frontend-api/service/graphql`
  - In der Capture mehrfach aufgerufen (GraphQL)
  - Primär-Kandidat fuer:
    - Buchungsliste / "Meine Reisen" (Tripdetails)
    - Details (Storno-Infos, ggf. Raten/Hotel-Offsets)

- `https://www.opodo.de/travel/service/frontendapi/getVisitInformation`
  - Wirkt wie ein Visit/Context-Endpoint (Session-Kontext)

Zudem enthält die Capture:
- HTML Login-Seitenaufruf und Redirects (u.a. Google Sign-In Seite)

Status / Rest:
- Login-SSOT: Homepage `https://www.opodo.de/` (nicht `/travel/secure/` — dort Login-Modal über Checkout-HTML).
- Primär: GraphQL `getTrips` (Session via WebView-Cookies auf der Homepage).
- HTML-Fallback nur wenn `getTrips` **0 Trip-Rows** liefert. GraphQL-Fehler (inkl. `USER_NOT_LOGGED_IN`) nicht per HTML ersetzen.
- Katalog nur Flug (`transportTypes: PLANE`) und Hotel; `insuranceBookings` und Vehicle-/Transfer-Offers nicht syncen.

## Booking.com (secure.booking.com / account.booking.com / flights.booking.com) - relevante Anker

Gefundene Anker aus HAR (u. a. Capture 2026-07-20):

- Login-/Mytrips Seite (HTML):
  - `https://secure.booking.com/mytrips.de.html`
  - Apollo-Client: `b-trips-frontend-trip-xp-mfe` (+ Version-Suffix im Capla-Namespace)

- Katalog / Trip-Liste (GraphQL):
  - `POST https://secure.booking.com/dml/graphql`
  - Operation `GetTripsQuery` → `tripsQueries.getTrips.trips[]`
    - Stages wie im Browser: zuerst `["CURRENT","UPCOMING"]`, dann `["PAST"]` (nicht einzeln CURRENT/UPCOMING)
    - Pagination via `nextPageData.paginationToken` (`rowsPerPage` 10)
    - SSR-Fallback: `trip_id=` im My-Trips-HTML (nicht die Marketing-Texte „Wohin geht es…“ als Empty-Signal)

- Trip-Timeline mit Reservierungen (GraphQL):
  - Operation `SingleTimelineQuery` → `singleTripTimelineQueries.singleTripTimeline`
  - Live 2026-08: V1 weiterhin gültig; MFE enthält zusätzlich `SingleTimelineQueryV2`. In einem Konto u. a. `FlightReservation`, `AccommodationReservation`, `PrebookTaxiReservation` — siehe [`dev/bookingcom-mytrips-audit.md`](dev/bookingcom-mytrips-audit.md).

- Flug-Confirmation / Storno (REST):
  - `GET https://flights.booking.com/api/order/{orderToken}?pb=1&cancellationOptionsType=1`
  - Order-Token aus Confirmation-URL `flights.booking.com/confirmation/{token}`

- Hotel-Confirmation (HTML + Post-Booking GraphQL):
  - `https://secure.booking.com/confirmation…?auth_key=…`
  - Fee-Schedule / `FREE_CANCELLATION` im HTML; ergänzend `SelfServiceBannerQuery` u. a.

- Identity / OTP Endpunkte (für Login, 2FA):
  - `https://account.booking.com/api/identity/authenticate/v1.0/otp/is-enabled?...`
  - `https://account.booking.com/api/identity/authenticate/v1.0/otp/email/submit?...`
  - `https://account.booking.com/api/identity/authenticate/v1.0/otp/code/submit?...`

Zudem sind Cookie-Namen/Session-Strings in Headern sichtbar (keine Credentials, aber Session-Kontext):
- `bkng_sso_auth`, `bkng`, `bkng_sso_session`, `bk_nav_search`, `aws-waf-token`, etc.

Status:
- Primärpfad in der App: `GetTripsQuery` + `SingleTimelineQuery` (Trip-XP MFE); HTML-Fallback nur wenn GraphQL leer/fehlschlägt.
- Flug-Storno über Order-API; Hotel-Storno aus Timeline-`policy` und Confirmation-HTML.

## Check24 Kontext (Referenz, kein Ziel in diesem Doc)

- Check24 zeigt in bestehender Implementierung:
  - Katalog via `https://kundenbereich.check24.de/kb/api/activities`
  - Storno-/Policy-Details via HTML Snapshots pro Booking

