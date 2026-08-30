# Storno-Portal-Link und Öffnen-/Storno-Buttons

Datum: 2026-08-30  
Status: Entwurf (`/feature-dev`, P1)  
Plattformen: macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`)

## Ziel

1. Die **Buchungserkennung** (Catalog/Enrich → `ProviderBookingDraft`) jedes Sync-Providers persistiert einen **direkten HTTPS-Link zur Storno-/Refund-Seite** dieser Buchung, sofern der Pfad im Provider-Modul belegbar ist.
2. Die Buchungs-UI hat zwei HIG-konforme Aktionen:
   - **Öffnen-Button** — öffnet `Booking.externalUrl` (bestehende Portal-Buchung).
   - **Storno-Button** — öffnet `Booking.cancellationUrl` (Storno-/Refund-Flow beim Anbieter).
3. Storno in Reisen bleibt **Lesen/Öffnen**. Die App storniert die Buchung nicht selbst.

Verwandt, nicht dieser Intent: [booking-portal-open.md](../../dev/booking-portal-open.md) (nur Öffnen + Gap-Suche). Löschen in Reisen: [booking-trip-delete-design.md](2026-08-28-booking-trip-delete-design.md) (explizit Out of Scope „Provider-Portal stornieren“).

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---------|-----------|
| **Öffnen-URL** | `Booking.externalUrl`, gefiltert über `BookingExternalURL.browserURL` (kein `reisen://manual/`). |
| **Storno-URL** | `Booking.cancellationUrl`, **derselbe** Filter `BookingExternalURL.browserURL`. Direkter Einstieg in den Storno-/Refund-Flow **dieser** Buchung. |
| **Öffnen-Button** | Sichtbares Control (Link mit Button-Stil) mit kurzem Titel „Öffnen“ / „Open“. |
| **Storno-Button** | Analog, Titel „Storno“ / „Cancel in portal“. Öffnet die Storno-URL. **Kein** `role: .destructive`, **kein** Confirm. |
| **Sync-Provider** | `ProviderID.syncProviderIDs` (Check24, Opodo, Booking.com, Airbnb, GetYourGuide, Traveloka, billiger-mietwagen.de). |
| **Belegte Storno-URL** | Pfad steht in dem Provider-Web-SSOT **und** ein Test belegt ihn gegen Fixture/HAR-String; oder der Extract liefert ein explizites href/API-Feld. |
| **Unbelegt** | `cancellationUrl == nil`. Storno-Button ausgeblendet. Kein Dummy, keine Kopie der Öffnen-URL. |

## Anforderungen

### In Scope (v1)

- Optionales Domain-Feld `cancellationUrl: String?` auf `Booking`, `ProviderBookingFacts`, `ProviderBookingDraft`, `ProviderBookingEnrichment`.
- Persistenz: optionales Attribut `SDBooking.cancellationUrl` (Cloud-Model, lightweight wie `operatorName`).
- Upsert über bestehende Nachbarn: `DraftAssembler`, `apply(_ enrichment:)`, `SyncBookingDraftFieldCopy`, `DomainMapper`, `SwiftDataBookingFieldApply.applyIdentity`.
- **Sync löscht keine persistierte Storno-URL:** `draft.cancellationUrl == nil` (unbelegter Provider) überschreibt `booking.cancellationUrl` nicht. Nur eine nicht-leere, `browserURL`-taugliche Draft-URL ersetzt den Bestand (`assignNonEmpty`, analog Enrichment). Editor-Nachtrag überlebt den nächsten Sync.
- Jeder Sync-Provider: Extract setzt die Storno-URL, wenn belegbar (Matrix unten). Enrichment überschreibt Katalog nur wenn die Enrich-URL nicht leer ist (`assignNonEmpty`).
- Traveloka: `TravelokaAPI.refundPresubmissionURL` **immer** als Storno-URL setzen, sobald `productType` / `bookingId` / `itineraryId` bekannt sind — unabhängig davon, ob der Refund-HTML-Fetch Fristen liefert.
- UI-Einstiege — **ActionBar unabhängig von der Öffnen-URL** (nur-Storno nach Editor-Nachtrag ist gültig):
  - macOS Inspector (`BookingDetailContent`) — ActionBar immer; Caption „kein Link“ nur wenn weder Öffnen- noch Storno-Control sichtbar
  - iOS Detail (`BookingDetailIOS` Links-Section) — dasselbe; nicht hinter `if let browserURL`
  - macOS Kontextmenü Timeline + Sidebar + Offen (`TripDetailView`, `ContentView`)
  - iOS Kontextmenü Timeline + Offen (`TripDetailIOS`, `OffenTab`)
  - macOS Command: FocusedValue aus der **selektierten `SDBooking`** (beide URLs + `booking.status`), nicht nur aus `browserURL`
- Manueller Editor: optionales Textfeld Storno-URL neben der bestehenden Buchungs-URL.
- L10n DE+EN, keine Hardcodings.

### Nicht in Scope

- In-App-Storno, Provider-Cancel-API, Tombstones.
- `role: .destructive` oder `confirmationDialog` für das Öffnen der Storno-Seite (die Destruktion passiert beim Anbieter).
- Storno-URL = Öffnen-URL (stilless Fallback). Zwei Buttons, die dieselbe URL öffnen, sind verboten.
- Storno-Button bei `BookingStatus.cancelled`.
- Neue `LSApplicationQueriesSchemes`.
- Paste-Import-`@Generable`-Feld (v1 `open_gaps`; manuelles Editor-Feld deckt Nachtragen).
- Gap-Suche, F15 Flighty.
- XCUI / UI-Test-Target.

## Architektur

```
Provider-Extract ──► ProviderBookingFacts.cancellationUrl
                 └──► Enrichment.cancellationUrl (assignNonEmpty)
                              │
                              ▼
                 ProviderBookingDraft ──► SyncBookingDraftFieldCopy
                              │
                              ▼
                 Booking.cancellationUrl ──► SDBooking (Cloud)
                              │
                              ▼
                 BookingExternalURL.browserURL
                              │
              ┌───────────────┴───────────────┐
              ▼                               ▼
     Öffnen-Button (externalUrl)     Storno-Button (cancellationUrl)
              └── SwiftUI Link + .buttonStyle + openURL (macOS Browser / iOS UL-or-Safari)
```

Schicht-Landung:

| Was | Wo |
|----|-----|
| Feld, Filter, Titel-SSOT | `ReisenDomain` |
| URL-Bau / Extract | jeweiliges Provider-Modul (`*Web` / `*API`, Parser) |
| Persistenz / Mapper | `ReisenData` |
| Controls | `ReisenSharedUI` (`BookingPortalOpenLink.swift` erweitern, kein zweites Open-Modul) |
| Verdrahtung | `Reisen`, `ReiseniOS` |
| Doku-Matrix | `docs/dev/booking-portal-open.md` (Abschnitt Storno ergänzen) |

Domain bleibt SwiftData-/WebKit-frei. Kein neues Modul. Kein paralleler URL-Opener neben `openURL`.

### Filter (kein zweiter Policy-Pfad)

`Booking.cancellationBrowserURL` ruft **nur** `BookingExternalURL.browserURL(from: cancellationUrl)` auf. Manuelle Pseudo-URLs und leer/whitespace → `nil`.

Sichtbare Controls (SSOT, Domain, von der View nur gerendert):

```
BookingPortalActions.visible(open:cancellation:status:) -> (open: URL?, cancel: URL?)
```

- `open`: `BookingExternalURL.browserURL` der Öffnen-URL (kann nil sein).
- `cancel`: nur wenn `BookingPortalCancellation.isActionable` (nicht cancelled, cancel ≠ open, cancel ≠ nil).

Die ActionBar zeichnet genau diese beiden Optionals. Tests belegen die Kombinationen: nur Öffnen, nur Storno, beide, keine, cancelled, gleiche URL.

### Schema

Optionales String-Attribut auf `SDBooking`. Hybrid-Store bleibt `Schema(ReisenSchemaV9.models)` — gleiche lightweight-Regel wie `operatorName` / `isAllDay` ([swiftdata-hybrid-cloudkit.md](../../dev/swiftdata-hybrid-cloudkit.md)). Kein neues Model, kein Wipe als Happy Path.

## Provider-Matrix (v1)

Belegpflicht: Template oder Extract **nur** mit Fixture- oder HAR-String. Lokale gitignored HARs dürfen das Muster liefern; ins Repo kommt eine redigierte Assertion, nicht die HAR.

| Provider | Storno-URL | Quelle |
|----------|------------|--------|
| Traveloka | `…/refund/presubmission/{PRODUCT}/{bookingId}/{itineraryId}` | `TravelokaAPI.refundPresubmissionURL` |
| Airbnb Experience | `…/experience_alteration/{confirmationCode}?flow=oneCancel&productType=experience` | HAR `skinny_row.cancel_reservation.app_url` (Host = `AirbnbAPI.baseURL`); Browser: Pfad ist Storno-UI, nicht 404 |
| Airbnb Stay | unbelegt | HAR ohne Stay-Cancel-Click; geratener Pfad `/reservation/cancel/{code}` ist 404 |
| Check24 | unbelegt | bestehende Fixtures/HARs ohne Storno-href; Capture: Kundenbereich-Buchung → Storno klicken |
| Booking.com | unbelegt | Capture: Confirmation → „Cancel your booking“ |
| GetYourGuide | unbelegt | HAR: Cancel ist In-Page-Modal auf Open-URL (verboten als Storno-URL). Capture: nach Klick auf Cancel, ob eigene HTTPS-URL entsteht |
| Opodo | unbelegt | Capture: My Trips → Manage booking → Cancel my trip |
| billiger-mietwagen.de | unbelegt | Capture: Meine Buchungen → Buchung stornieren |
| Manual | Editor-Feld | kein Sync |

Fehlt der Beleg: `nil` + Catalog-Test `cancellationUrl == nil` (kein Raten, kein Open-URL-Kopie). Capture-HAR lokal `HAR/` (gitignored); ins Repo nur redigierte Assertion.

**Pflicht mit belegter URL:** Traveloka (alle Produkttypen mit IDs) und Airbnb **Experience**. Übrige Sync-Provider: Pipeline + nil-Test bis HAR/Browser den **buchungsspezifischen** Pfad belegt.

## HIG

Leitplanken: bestehendes Open ([booking-portal-open.md](../../dev/booking-portal-open.md), HIG-Core-UX), Apple HIG Buttons vs. Links.

- Semantik **Link** (verlässt die App): SwiftUI `Link` mit `Label(..., systemImage: "arrow.up.right.square")`. Button-Stil über Parameter `openButtonStyle`: macOS Inspector `.bordered`; iOS Detail-Öffnen `.borderedProminent`; Storno immer `.bordered`. VoiceOver-Trait Link bleibt.
- Kurztitel **an den Buttons**: `action.open_short` = „Öffnen“ / „Open“; `action.cancel_in_portal` = „Storno“ / „Cancel in portal“. Keine langen Open-Titel auf der ActionBar.
- Lange Titel nur **Menü/Command** (bestehende Open-Keys; `action.cancel_in_portal_menu` = „Stornieren im Portal“ / „Cancel in portal“).
- `.help`: macOS Open = `action.open_in_browser_help`; Storno = `action.cancel_in_portal_help` (öffnet Anbieter-Seite, storniert nicht in Reisen).
- Kontextmenü Copy: bestehendes `action.copy_link` nur für die Öffnen-URL; Storno-URL eigener Key `action.copy_cancellation_link` („Storno-Link kopieren“ / „Copy cancellation link“). Keine zwei identischen „Link kopieren“.
- Kein Confirm, kein destruktiver Role, kein `xmark`.
- Fehlendes Control **weg**. Leer-Caption nur wenn `visible` beide nil. Command/Menü: disabled + Help „kein Link“.
- iOS Store: Buttons über iCloud-Felder, ohne Provider-Registry.
- macOS: Inspector-Action-Bar, nicht Caption-only-Textlink.

SharedUI: `BookingPortalActionBar` rendert `BookingPortalActions.visible`. `openButtonStyle` ist Pflichtparameter.

## Fehler und fehlende Daten

- Unbelegte Storno-URL im Draft → persistierte URL **behalten**, Button nur wenn Bestand `browserURL` hat; kein `??` auf `externalUrl`.
- Traveloka Refund-Fetch fehlgeschlagen → Storno-URL trotzdem setzen (die Seite existiert); Fristen-Verhalten unverändert.
- Ungültige/manuelle Strings → `browserURL == nil` → kein Button.
- Persistenzfehler: bestehende Delete/Save-Alerts, dieser Pfad ändert Save nicht.

## Tests

- Domain: `cancellationBrowserURL` nutzt denselben Filter; Manual-Prefix → nil; `BookingPortalActions.visible` und `isActionable` (nur Öffnen, nur Storno, beide, keine, cancelled, gleiche URL).
- Assembler/Enrichment: Feld durchgereicht; leeres Enrich löscht Katalog-URL nicht.
- Upsert: Roundtrip; Draft-`nil` lässt bestehende `cancellationUrl` stehen.
- Traveloka: Draft/Enrichment hat Refund-URL ≠ Detail-URL.
- Übrige Provider: Fixture-Test URL oder explizit `nil`.
- Titel: `BookingPortalCancelTitle` analog `BookingPortalOpenTitleTests` (Key ≠ sichtbarer String, DE/EN über Locale-Override wie bestehende Tests).
- Plist: keine neuen Query-Schemes.

## Schnittstellen-Inventar

| id | kind | supply | evidence |
|----|------|--------|----------|
| open-button | entry | ActionBar/Menü/Command → `Link`/`openURL` der `visible.open`-URL | `BookingPortalActions.visible`-Tests (open gesetzt) + verdrahtete Views |
| cancel-button | entry | dieselben Einstiege für `visible.cancel` | `visible`-Tests inkl. nur-Storno ohne Open-URL + verdrahtete Views |
| editor-cancellation-url | entry | `BookingEditor` TextField → `apply`/`createBooking` | Roundtrip `fromExisting` / `createBooking` in SharedUI-Tests |
| openurl-capability | capability | bestehendes openURL; keine neuen Schemes | `AppStoreComplianceInfoPlistTests` |
| cancellation-url-contract | contract | Filter + `isActionable` + Sync löscht nil nicht | Domain-Tests |
| provider-extract | contract | je Sync-Provider Draft/Enrichment | Parser-/Catalog-Tests |
| upsert-neighbor | neighbor | bestehende Upsert/Mapper | erweiterte Tests |

Nicht port-only. Profil `unstructured_input` / `live_app` nicht geladen.

## Offene Lücken (`open_gaps`)

- Paste-Import setzt `cancellationUrl` nicht.
- AASA für Storno-Pfade unbelegt (Safari-Fallback ok).
- Provider ohne Fixture-/HAR-Beleg: `nil` bis ein Beleg existiert.
- HAR-Capture (Safari/Firefox, eingeloggt, eine Buchung, **Storno/Cancel klicken**, HAR speichern nach `HAR/`): Check24, Booking.com, Airbnb Stay, GYG (nur wenn nach Klick eine **andere** URL als `/booking/{hash}`), Opodo, billiger-mietwagen.de.

## Akzeptanz

1. Traveloka-Sync persistiert eine Storno-URL ungleich der Öffnen-URL; Storno-Button öffnet sie.
2. Jeder andere Sync-Provider hat einen Test: belegte URL oder bewusst `nil`.
3. Öffnen-Button öffnet weiterhin nur `externalUrl`.
4. Kein Storno-Button ohne URL, bei gleicher URL wie Öffnen, oder bei Status cancelled. Nur-Storno ohne Öffnen-URL zeigt den Storno-Button.
5. macOS und iOS: Detail + Listen-Kontextmenüs; macOS zusätzlich Command aus voller Buchungsselektion.
6. Strings nur L10n DE+EN. Kein in-App-Storno.
7. Sync mit `cancellationUrl == nil` lässt eine persistierte/Editor-Storno-URL stehen.

## Alternativen (verworfen)

| Ansatz | Grund gegen |
|--------|-------------|
| Storno-Button öffnet `externalUrl` | Stilless Fallback; zwei Labels, eine URL. |
| `role: .destructive` + Confirm | Impliziert Storno in Reisen; HIG-falsch für „Seite öffnen“. |
| Eigenes `BookingCancellationURL`-Filter-Enum | Duplikat von `BookingExternalURL.browserURL`. |
| In-App Cancel-API | Keine belegte API; Store-/Auth-Risiko; Out of Scope Delete-Spec. |
| Nur Traveloka | Widerspricht „alle Provider“ (Pipeline); UI darf trotzdem nur bei Beleg zeigen. |
