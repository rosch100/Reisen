# Check24 Hotel-Navigation-Timeout — Design

Datum: 2026-09-06

## Problem

Sync-Log Run `0B480983` (2026-09-06T08:24:18Z–08:24:51Z): Check24 Activities-API ok, Hotel-Detail auf Ziel-URL (`target=true`) bleibt `isLoading=true`. Nach 32 s `Navigation-Timeout` — der gesamte Check24-Catalog failt. UI zeigt den Sync-Spinner.

## Erwartete Semantik

1. Navigation ist angekommen, wenn Host+Pfad matchen (`NavigationTargetMatching.isOnTarget`).
2. `WKWebView.isLoading == true` nach Ankunft (SPA, Subresources, XHR) ist kein Navigation-Fail.
3. DOM-Bereitschaft bleibt Check24-`waitForHotelDetailReady` (bestehende JS-Bedingung).
4. Ein Hotel-Navigation-Timeout (`NavigationSettleTimeout`) bricht `fetchCatalog` nicht. `CancellationError` und andere Enrich-Fehler werden weitergeworfen.
5. `publicDiagnostic` loggt keine 100-ms-`poll`-Events.

## Nicht in diesem Fix

Opodo-Apple-SSO, Traveloka-Zweistufen-Autofill, BMW-Session-Cookie-Reprobe (fremde /bugfix-Sessions). Opodo-GraphQL-60s-Timeout, Traveloka-Catalog-401, Check24-Autofill-Race, SyncLog-Rotations-Schnitt — eigene Workstreams.

## Ansatz

- `NavigationSettleReady`: on-target + (sawLoading oder URL) + (`!isLoading` **oder** on-target länger als Grace, Default 2 s).
- `NavigationSettleConfirm`: nach 350 ms dieselbe Accept-Regel, nicht hart `!isLoading`.
- `NavigationSettleLoop`: bei Deadline on-target → Erfolg statt Timeout; einmal `deadline_on_target`, kein 100-ms-Flood.
- Check24 `enrichHotelBookings`: per-Buchung `catch` nur für Navigation-Timeout; Cancellation und andere Fehler weiterwerfen.
- Loop: `url_changed` / `loading_changed` / `target_match_changed` und einmal `deadline_on_target`; kein `poll`.
