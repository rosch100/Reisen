# Implementation-Spec: billiger-mietwagen.de Consumer-Sync

Status: **Umgesetzt** (SPM-Target `ReisenBilligerMietwagen`).  
HAR/Research: [`API_Research_Provider_Candidates.md`](../API_Research_Provider_Candidates.md) § A.4.  
Fixtures: [`../fixtures/provider-research/bm_*.json`](../fixtures/provider-research/).

## Ziel

Neuer Provider `ReisenBilligerMietwagen` / `ProviderID.billigerMietwagen`: persönliche Mietwagen-Buchungen (FLOYT) über WKWebView-Login, Cookie-Session (`session.php`) und Bearer-Calls gegen `consumer-api.floyt.com`.

## Primärpfad (ein Pfad)

Cookie-Session der WebView → `GET /user_account/session.php` → `access_token` → JSON-API Buchungsliste + Web-Detail. **Kein** HTML/`__NEXT_DATA__`-Zweitpfad.

## Surfaces

| Schritt | URL | Parse |
|---------|-----|-------|
| Login-Start | `https://www.billiger-mietwagen.de/reservation/account/login` | Interaktives WKWebView (E-Mail/Passwort; optional Apple/Google) |
| Login API (nur SPA/WebView) | `POST https://consumer-api.floyt.com/auth/v1/login` | Body `{username,password}`; Header `X-Whitelabel: DE_billiger-mietwagen`, `client-id: web`, `Origin: https://www.billiger-mietwagen.de` → `{access_token,refresh_token,id_token}` |
| Session schreiben (SPA nach Login) | `POST https://www.billiger-mietwagen.de/user_account/session.php` | Body `{access_token,refresh_token}` → `[]` + `Set-Cookie` (`__Secure-billigermietwagen`, `__Secure-user_account`) |
| Session lesen (Sync/Probe) | `GET …/user_account/session.php` | `access_token` / `refresh_token` — **nicht** persistieren/loggen |
| Catalog (active) | `GET …/useraccount/v1/bookings?activity_status=active&sort_by=PickupDate&sort_order=asc&page=N&limit=10` | `items[]` + `_pointers` (alle Seiten bis `next`/`last`) |
| Catalog (inactive) | `GET …/bookings?activity_status=inactive&sort_by=DropOffDate&sort_order=desc&page=N&limit=10` | wie active (SPA-Parität; stornierte Drafts droppt Domain) |
| Token-Refresh | `POST …/auth/v1/refresh-token` | 201 mit `access_token` (und `id_token`); `refresh_token` in der Antwort oft **fehlt** — dann den verwendeten Refresh weiterverwenden |
| Enrich | `GET https://consumer-api.floyt.com/useraccount/v1/web/bookings/{id}` | Web-Detail JSON |
| Site settings (SPA) | `GET https://api.billiger-mietwagen.de/v1/site/settings` | Sync nicht nötig |

Header für Consumer-API (Catalog/Enrich): `Authorization: Bearer {access_token}`, `X-Whitelabel: DE_billiger-mietwagen`, `client-id: web`, `Origin: https://www.billiger-mietwagen.de`, `Accept: application/json`.

**Token-Refresh (Live 2026-08-28):** `session.php`-`access_token` allein liefert an der Consumer-API oft **401**. Sync macht daher einmal pro Lauf `POST …/auth/v1/refresh-token` mit `{ refresh_token, user_id }` wobei `user_id` = JWT-Claim **`username`** (nicht `sub`). Die API antwortet **201** mit `access_token` + `id_token` und **ohne** neuen `refresh_token` (Cognito rotiert hier nicht; die SPA liest nur `access_token`). Sync cached den neuen Access-Token und schreibt per `POST session.php` den neuen Access plus den weiterhin gültigen Refresh (neuen Refresh nur wenn die Antwort einen liefert). Anschließend Catalog **active** + **inactive** inkl. Pagination über `_pointers`.

Passwort-Login wird **nicht** außerhalb der WebView nachgebaut; die SPA führt Login-API + Session-POST aus (HAR 2026-08-28).

## Target / Package

1. SPM-Target `ReisenBilligerMietwagen` (Domain, Providers)
2. `ProviderID.billigerMietwagen` (`rawValue` `billigermietwagen`), Logo, Registry
3. Keychain-Host `billiger-mietwagen.de`

## Catalog-Mapping (`items[]`)

`activity_status=active` und `inactive`, danach `ProviderCatalog.dedupedByExternalURL()` (bei BM ist `externalUrl` = `/reservation/account/bookings/{id}`, also id-gleich). Einträge mit `status` `error` überspringen; fehlendes/anderes `type` als `car_rental` ebenfalls. `canceled`/`cancelled` werden von `CatalogListing` sowieso gedroppt.

| API | Reisen |
|-----|--------|
| `type` `car_rental` | `BookingType.carRental` |
| `reservation_id` | `confirmationCode` |
| `/reservation/account/bookings/{id}` | `externalUrl` |
| `pick_up.date` / `drop_off.date` (ISO+Offset) | `startAt` / `endAt` — ohne Offset oder fehlendes Ende → skip |
| `pick_up.city` / `drop_off.city` | `locationFrom` / `locationTo` |
| `supplier.name` (sonst `provider.name`) | `operatorName` |
| `vehicle.car_class` | `rateDetails.roomCategory` (Mietwagen-Kategorie) |
| `price.total.amount` / `currency` | Rate |
| `status` `confirmed` / … | `BookingStatus.parse` |

## Enrichment (Web-Detail)

| Quelle | Mapping |
|--------|---------|
| `offer.model` | `title` (Katalog-Route `Berlin → München` bleibt, Enrich überschreibt nur bei non-empty model) |
| `offer.supplier` / `offer.provider` | `operatorName` |
| `offer.transmission` | `rateDetails.roomCategory` (überschreibt Klasse wenn gesetzt) |
| `rental.pickUp` / `dropOff` address | `locationFrom`/`To` + Adressen |
| `reservation.cancelUntil` | **Primäre** `CancellationDeadline` = Portal „kostenlos stornieren bis …“; ohne Offset → Katalog-Pickup-Offset; `isFreeCancellation` nur bei `offer.free_cancellation` |
| `offer.free_cancellation` + `free_cancellation_hours` | Fallback-Deadline (feste Stunden-Dauer vor Pickup) nur ohne `cancelUntil`; GuestHint Stunden nur ohne `cancelUntil` |
| `driver.name` | `passengers` (ein Eintrag, `travellerType` adult; ohne PII in Logs/Fixtures) |
| `files.voucher.url` | GuestHint „Voucher“ (nur Allowlist-Hosts `*.floyt.com` / Portal) |

Detail-`datetime` ohne Offset: Zeiten aus dem Katalog behalten; keine UTC-Annahme.

## Auth / Session

- Cookie-Session der WebView für `session.php`; Bearer nur transient für API-GETs. Consumer-API und Session-Calls senden HAR-SPA-Header `Origin` + `client-id: web` (Refresh zusätzlich `X-Whitelabel`).
- **Kein CSRF/XSRF-Header** in der Login-/API-HAR: Auth läuft über Session-Cookies + Bearer + `X-Whitelabel` + SPA-`client-id`/`Origin`. Keine Token-Werte aus HAR hardcoden.
- Tokens nicht in Keychain (nur optionales Remember-Login der App für Portal-Passwort).
- IdP-Hosts (Apple/Google) nicht `sessionReady` (`AuthIdentityProviderHost`).
- URL-Heuristik: Portal-Hosts inkl. Login `/reservation/account/login`, Bookings und Homepage → `shouldProbeBilligerMietwagen` (`session.php`). Die SPA zeigt Buchungen oft weiter unter der Login-URL; kein `needsLogin` nur wegen des Pfads, kein blindes `sessionReady` nur wegen Account-Pfad.
- Unklare Portal-URLs, Login- und Account-Seiten: `BilligerMietwagenSessionProbe` via `GET session.php` mit demselben Referer wie Sync (`/reservation/account/bookings`) plus SPA-Header. Access- **und** Refresh-Token non-empty, gleicher Vertrag wie Sync.

### Cookie-Banner / Consent

- Das Portal zeigt einen Cookie-/Consent-Banner. **Ungedismissed Banner blockiert** zuverlässiges Login und Sync in der eingebetteten WebView (gleiche Beobachtung wie bei anderen Portalen).
- Reisen dismiss’t den Banner **nicht** automatisch (kein DOM-Hack). Der Nutzer schließt den Banner interaktiv beim WebView-Login.
- Nach Consent: SPA-Login wie Surfaces; danach Cookies für `session.php` und Consumer-API.

## Tests

- `bm_bookings_active_redacted.json` → Drafts
- `bm_booking_detail_web_redacted.json` → Enrichment (inkl. Fahrer/Voucher-Hints)
- Session-Fixtures nur Shape (`access_token` redacted)
- Keine echten Tokens/Hashes in Assertions

## Nicht in Scope

- Partner-/Demand-API
- Quotes `/reservation/quotes/`
- Gast-Lookup Buchungsnummer+Nachname
- Kontaktlose App-Verifikation
