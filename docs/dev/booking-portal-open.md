# Buchungs-Portal öffnen & Gap-Suche

Stand: 2026-09-09

Zwei getrennte HTTPS-Pfade:

1. **Buchung öffnen** — persistiertes `Booking.externalUrl` → `BookingExternalURL.browserURL` → SwiftUI `openURL` / `BookingPortalOpenLink`
2. **Gap-Suche** — `GapDeepLinkBuilding` baut öffentliche Such-URLs mit Prefill aus `GapContext`; Filter nach `GapKind` + aktivierten Providern

Keine Custom-Scheme-Buchungs-URLs. iOS folgt Universal Links (AASA); sonst Safari. macOS immer Standard-Browser.

Storno ist ein zweiter HTTPS-Pfad, nicht `externalUrl`.

App-Store-iOS: keine Provider-Registry → keine Gap-Suche; Buchungs-Open über iCloud-`externalUrl` weiterhin möglich. `LSApplicationQueriesSchemes` nur Private-iOS.

## Buchungs-Open (Provider × URL-Form × iOS-App)

| Provider | Typische `externalUrl` | macOS | iOS App (AASA) |
|----------|------------------------|-------|----------------|
| Airbnb | `https://www.airbnb.de/trips/v1/{id}/ro/{type}/{code}` | Browser | Ja (`/trips/v1/*` auf airbnb.de) |
| Booking.com Hotel | `https://secure.booking.com/confirmation.html?…` | Browser | Nein → Safari |
| Booking.com Flug | `https://flights.booking.com/confirmation/{token}` | Browser | Ja (`/confirmation/*`) |
| Check24 Hotel | `https://hotel.check24.de/kundenbereich/buchung/{uuid}` | Browser | unklar / Browser-Fallback |
| Check24 Flug | `https://flug.check24.de/kundenbereich/buchung/{uuid}` | Browser | unklar / Browser-Fallback |
| Check24 Fähre | `https://ferry.check24.de/kundenbereich/buchung/{uuid}` | Browser | unklar / Browser-Fallback |
| GetYourGuide | `https://www.getyourguide.com/en-us/booking/{hash}` | Browser | best-effort |
| Traveloka | `…/item/details/{bookingId}?type=&id=` | Browser | best-effort |
| Expedia | `…/trips/{egti}/details/{tripItemId}` | Browser | best-effort |
| Opodo | `…/travel/secure/#tripdetails/td={token}` | Browser | Nein (Hash) → Safari |
| Manual | `reisen://manual/{uuid}` | kein Open | kein Open |

GYG ohne `bookingHash`: kein Katalog-Draft. Airbnb ohne ableitbare Portal-URL: Draft bleibt (`externalUrl` nil). Open-UI nur bei `browserURL`.

## Buchungs-Storno (Provider × Storno-URL × Button)

Persistiertes `Booking.cancellationUrl` → `BookingExternalURL.browserURL` → `BookingPortalActions.visible` / Presentation. Filter identisch zu Open. Guard: Status, anzeigbare Fristen; Sheet bei Hub-Session auch wenn Cancel-URL = Open-URL (In-Page); Safari nur bei eigener Storno-Seite ohne Session-Zwang. Der Button storniert nicht in Reisen.

**SSOT-Matrix:** [2026-08-31-provider-cancellation-links-all-design.md](../superpowers/specs/2026-08-31-provider-cancellation-links-all-design.md).

| Provider | Storno-URL-Form | Button |
|----------|-----------------|--------|
| Traveloka | `…/refund/presubmission/{PRODUCT}/{bookingId}/{itineraryId}` | ja, wenn actionable (≠ Open) |
| Airbnb Experience | `…/experience_alteration/{code}?flow=oneCancel&productType=experience` | ja, wenn actionable (≠ Open) |
| Airbnb Stay | `…/alterations/stays/{code}/cancel` | ja, wenn actionable (≠ Open) |
| GetYourGuide | = Open-URL (In-Page-Modal) | ja, nur mit Hub-Session + Fristen |
| billiger-mietwagen | `…/reservation/account/bookings/{id}` (= Open; Assist → scoped Cancel) | ja, nur mit Hub-Session + Fristen |
| Expedia Hotel | `…/booking-servicing/lodging/voluntary/cancel/review?…` | ja, wenn actionable (≠ Open) |
| Expedia Mietwagen | `…/details/…/manage-booking` (= In-Page; Assist → Dialog/Confirm) | ja, nur mit Hub-Session + Fristen |
| Expedia Flug/Aktivität | `…/manage-booking` (Ableitung; kein Assist v1) | ja, nur mit Hub-Session + Fristen |
| Opodo | = Open-URL (`#tripdetails…`; Assist öffnet Bestätigungsdialog) | ja, nur mit Hub-Session + Fristen |
| Check24 | `…/kundenbereich/buchung/{uuid}?action=cancel` | ja, wenn actionable (≠ Open) |
| Booking.com Hotel | `…/cancel*.html?…auth_key=…` (aus Confirmation) | ja, wenn actionable (≠ Open) |
| Booking.com Flug | unbelegt | nein |
| Manual | Editor-Feld `cancellationUrl` | ja, wenn belegte HTTPS-URL und actionable |

Nur-Storno (ohne Open-URL) ist erlaubt bei distinct-URL, z. B. nach Editor-Nachtrag.

## Gap-Suche (Kategorie × Provider)

Menge = aktivierte Sync-Provider ∩ Builder. UI: Picker „alle aktiven“ oder ein Portal; Menü nach Kategorie.

| Kategorie | sichtbar bei GapKind | Builder |
|-----------|----------------------|---------|
| Hotel | lodging, both | Check24, Booking.com, Airbnb, Traveloka, Expedia |
| Flug | transport, both | Check24, Booking.com, Traveloka |
| Erlebnis | lodging, both | GetYourGuide, Traveloka |
| Fähre | transport, both | nur mit belegter öffentlicher URL (aktuell keine) |
| Mietwagen | transport, both | Expedia (nur mit konkreten Gap-Zeiten); sonst keine |

**Opodo:** kein Gap-Builder — öffentliche Prefill-Suche war nicht zuverlässig belegbar (kein Dummy).
**Expedia:** Hotel-Gap (`Hotel-Search`); Mietwagen-Gap (`carsearch/details`) nur wenn Gap konkrete Abhol-/Rückgabezeiten hat.

## Open-Titel (L10n-SSOT)

- macOS: `action.open_in_browser`
- iOS ohne App-Erkennung / Store: `action.open_booking`
- Private-iOS mit `canOpenURL`: `action.open_in_provider_app` (`%1$@` = Provider-Displayname)

Schemes: `ProviderNativeApp` (nur Erkennung, keine Open-Titel).
