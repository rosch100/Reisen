# Provider-Storno-Links: maximale Belegung (Hybrid)

Datum: 2026-08-31  
Status: Entwurf (brainstorming freigegeben; Review-Nachzug)  
Plattformen: macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`, Private und Store)

## Ziel

Alle Sync-Provider unterstützen den Storno-Einstieg **so gut wie belegt möglich**:

1. **Distinct Storno-URL**, wenn HAR/Fixture/Live-Beleg einen buchungsspezifischen HTTPS-Pfad ≠ Öffnen-URL liefert.
2. **In-Page-Cancel**, wenn Storno nur auf der Buchungsseite (Modal/Button) liegt: `cancellationUrl` bewusst gleich `externalUrl`, Storno nur über **Session-Sheet**.
3. Sonst `nil` — kein Raten, kein Dummy-Template.

Reisen storniert nicht selbst. UI-Semantik (Fristen-Gate, destruktives „Stornieren“, Sheet) bleibt in [2026-08-30-in-app-cancellation-sheet-design.md](2026-08-30-in-app-cancellation-sheet-design.md). Pipeline-Grundlage: [2026-08-30-cancellation-portal-links-design.md](2026-08-30-cancellation-portal-links-design.md) (diese Spec **ersetzt** deren Provider-Matrix und die Regel „nie Open-URL kopieren“ für dokumentiertes In-Page). Open-Matrix: [booking-portal-open.md](../../dev/booking-portal-open.md).

## Entscheidungen (Konsens)

| Thema | Wahl |
|-------|------|
| Strategie | Hybrid: echte Cancel-URLs **und** dokumentiertes In-Page |
| In-Page ohne Session | **Kein** Safari-Doppel-Open (HIG) |
| Persistenz In-Page | `cancellationUrl == externalUrl` bewusst setzen (Sheet-Spec), kein separates Cloud-Enum |
| Ableitung UI | URL + `cancel == open` + `hasSessionWebView` (bestehende Presentation) |
| Belegpflicht | Fixture/HAR/dokumentierter Live-Beleg; Capture nachziehen statt raten |
| Soft-Wave-1 | Kein „wenn ableitbar“ ohne Builder+Fixture → sonst Welle 2 |
| BM Safari | `/reservation/cancellation` ist **session-bound**; sichtbares Stornieren nur mit Hub-Session (wie In-Page) |

## HIG (kurz)

- Zwei Controls, die in Safari dieselbe URL öffnen: **verboten**; In-Page nur Session-Sheet.
- Destruktive Rolle, Titel, Help: Sheet-Spec (nicht hier neu definieren).
- Fehlendes Control **weg**, nicht disabled.
- „Storno-Link kopieren“ nur bei `cancel ≠ open`.
- Store ohne Hub: In-Page und session-bound distinct → kein Storno-Control (Öffnen bleibt).

## Begriffe

| Begriff | Bedeutung |
|---------|-----------|
| **distinctURL** | `cancellationUrl` HTTPS und ≠ `externalUrl` nach `browserURL`-Filter |
| **inPageOnOpen** | Cancel-Fläche = Buchungsseite; Extract setzt `cancellationUrl` auf dieselbe HTTPS-Open-URL |
| **sessionBoundDistinct** | Distinct-URL, die ohne Provider-Cookies nutzlos ist (z. B. BM Cancellation-SPA); Presentation wie In-Page: **nur Sheet** |
| **none** | `cancellationUrl == nil` bis Beleg existiert |
| **Policy-SSOT** | `ProviderCancellationLinkPolicy.mode(provider:bookingType:)` in **Domain** (neben `BookingPortalCancellation`); Provider-Module liefern nur URL-Builder |

Die ältere Portal-Links-Zeile „keine Kopie der Öffnen-URL“ gilt **nur** für `none`. Bei `inPageOnOpen` ist die Gleichheit Absicht, kein Dummy.

## Architektur

```text
ProviderCancellationLinkPolicy.mode(provider:bookingType:)
        → distinct | inPageOnOpen | sessionBoundDistinct | none
        │
Provider-Extract / Enrich (siehe Matrix: Catalog vs Enrich)
  → Facts.cancellationUrl
        │  distinct / sessionBoundDistinct: Template-URL
        │  inPageOnOpen: externalUrl (nur browserURL-tauglich)
        │  none: nil
        ▼
Draft → Upsert (nil wischt persistierte URL nicht;
         nächster Sync mit nicht-leerer Draft-URL füllt Backfill via assignNonEmpty)
        ▼
Booking.cancellationUrl
  → isActionable(status, deadlinesForDisplay)
  → presentation (erweitert um sessionBoundDistinct):
        Session → sheet (auch cancel == open; auch sessionBoundDistinct)
        kein Session + distinct (nicht session-bound) + cancel ≠ open → safari
        kein Session + (inPage | sessionBoundDistinct | cancel == open) → hidden
  → ActionBar / Menü / Cancel-Sheet load(URL)
  → allowsCopyingCancellationLink = (cancel != nil && cancel != open)
```

Kein neues SwiftData-Attribut. Store-iOS ohne Hub-WebView: nur nicht-session-bound distinct → Safari; sonst hidden.

### Presentation-API

Bestehende `BookingPortalCancellation.presentation` nimmt den Policy-Mode:

- Parameter `linkMode: ProviderCancellationLinkMode` (nicht nur Bool).
- `.none` → immer `.hidden` (auch bei persistierter Cancel-URL, z. B. Opodo-Rest).
- Session-bound / In-Page: ohne Hub-Session → `.hidden`; mit Session → `.sheet`.
- Distinct: ohne Session → `.safari`; mit Session → `.sheet`.

Empfehlung: Apps/SharedUI leiten `linkMode` aus `ProviderCancellationLinkPolicy.mode(provider:bookingType:)` ab (`Booking.provider` **und** `Booking.bookingType`). Kein Raten an der URL-Zeichenkette in der View.

## Provider-Matrix

Jeder Sync-Provider hat **genau einen** Mode pro `(provider, bookingType)`-Zelle. Kein „oder“.

| Provider | bookingType | Mode | Setzt | Beleg | Welle |
|----------|-------------|------|-------|-------|-------|
| Traveloka | * | distinct | Catalog (IDs bekannt) | `TravelokaAPI.refundPresubmissionURL` | 0 |
| Airbnb | `.activity` | distinct | Catalog (TripList) | `experience_alteration/…?flow=oneCancel` | 0 |
| Airbnb | `.hotel` (Stay) | none | — | Cancel-HAR fehlt; `/reservation/cancel/{code}` 404 | 2 |
| billiger-mietwagen.de | * | sessionBoundDistinct | Catalog oder Enrich (WebConstants) | Live `/reservation/cancellation` (keine Buchungs-ID; Session) | 1 |
| GetYourGuide | * | inPageOnOpen | Catalog (wenn `externalUrl` gesetzt) | HAR: Cancel-Modal auf `/booking/{hash}` | 1 |
| Opodo | * | none | — | `funnel=cancellationHSA` Live genannt, **kein** Fixture-Builder ohne Raten | 2 |
| Booking.com | `.hotel` | none | — | `cancel.html` Live-Kandidat, **kein** Fixture-Pfad | 2 |
| Booking.com | `.flight` | none | — | Cancel oft auf Confirmation; Capture nötig | 2 |
| Check24 | * | none | — | oft Kundenbereich-Seite; Capture nötig | 2 |
| Manual | — | distinct (Editor) | Nutzer | HTTPS-Feld | — |

**Welle 1 (verbindlicher Spec-Scope):** Policy-SSOT + Presentation `linkMode` (inkl. `.none` → hidden) + Copy-Helper + Docs-Folgen + Extract/Tests für **GYG (inPage)** und **billiger-mietwagen (sessionBoundDistinct)**. Traveloka/Airbnb Experience Regression.

**Welle 2:** Cancel-Click-HAR → Mode auf `distinct` / `inPageOnOpen` / `sessionBoundDistinct` umstellen; Opodo, Booking Hotel/Flug, Check24, Airbnb Stay.

### Welle-2 Capture (kurz)

Safari/Firefox, eingeloggt, **eine** aktive Buchung, Network an, **Storno/Cancel klicken** (nicht nur Detail), HAR nach `HAR/` (gitignored). Erfolg: Request-URL ≠ Open-URL **oder** belegt In-Page (keine Navigation). Ins Repo nur redigierte Test-Assertion.

## Komponenten

| Stück | Ort | Verantwortung |
|-------|-----|----------------|
| `ProviderCancellationLinkPolicy` | `ReisenDomain` | `mode(provider:bookingType:)`; optional `requiresProviderSession(mode:)` |
| URL-Builder | jeweiliges Provider-Modul (`*API` / `*WebConstants`) | Nur Templates mit Beleg |
| Parser / TravelProvider | Provider-Modul | Catalog und/oder Enrich laut Matrix |
| `BookingPortalCancellation` | Domain | Presentation + `allowsCopyingCancellationLink` + `linkMode`-Parameter |
| SharedUI ActionBar/Menü | SharedUI | Copy-Cancel nur bei erlaubt |
| Apps | macOS/iOS | Flag aus Policy + `booking.provider` / Typ |

## Fehler und Grenzen

- Weder ladbare distinct-/session-bound-URL noch (inPage) browserURL-taugliche Open-URL → kein Storno-Control.
- Keine anzeigbare Frist → hidden (bestehendes Gate).
- Sheet-Nav-Fehler → Fehler im Sheet, kein stiller Safari-Wechsel.
- Paste-Import setzt `cancellationUrl` nicht.
- Kein DOM-Auto-Klick auf Portal-Cancel.
- Kein Provider-Cancel-API / lokales `cancelled` durch diesen Flow.
- Opodo/Booking/Check24 in Welle 1 **nicht** per geratenem Query/Pfad befüllen.

## Tests

- Domain: Policy deckt alle `ProviderID.syncProviderIDs` × relevante Typen ab; Presentation (distinct Safari vs sessionBound/inPage hidden ohne Session); Copy-Regel.
- Welle 1: GYG `cancellationUrl == externalUrl` (bei Hash/Open); BM Cancellation-URL ≠ Open und Session-bound Mode; Traveloka/Airbnb Experience Regression.
- Negativ: Opodo/Booking/Check24/Airbnb Stay Catalog-Tests bleiben `cancellationUrl == nil` bis Welle 2.
- Keine HAR-Binaries im Repo.

## Akzeptanz (Welle 1)

1. `ProviderCancellationLinkPolicy` liefert für jeden Sync-Provider einen definierten Mode (Airbnb Stay = `none`, Experience = `distinct`).
2. GYG: bei Open-URL + anzeigbaren Fristen + Hub-Session erscheint Stornieren (Sheet); ohne Session kein Storno-Control.
3. billiger-mietwagen: persistierte Cancellation-URL ≠ Open; Stornieren nur mit Hub-Session; ohne Session hidden (kein Safari-Akzeptanzkriterium).
4. Kein Safari-Open für Stornieren, wenn `cancel == open` oder Mode session-bound.
5. Copy-Storno-Link fehlt bei `cancel == open`.
6. Opodo/Booking/Check24/Airbnb Stay: weiterhin `nil` in Catalog-Tests (kein Raten).

## Doc-Folgen (gleiche Änderung / Folge-Commit)

1. [2026-08-30-cancellation-portal-links-design.md](2026-08-30-cancellation-portal-links-design.md) — Matrix und Akzeptanz an Hybrid/In-Page anpassen; Verweis auf diese Spec.
2. [booking-portal-open.md](../../dev/booking-portal-open.md) — Storno-Tabelle an Matrix hier.
3. Sheet-Spec — Querverweis „URL-Extract: diese Spec“; BM als session-bound distinct erwähnen.

## Nicht in Scope

- Welle-2-HARs als Blocker für Welle 1.
- Schema-Enum für Cancel-Mode.
- XCUI / automatisches Klicken im Portal.
- Änderung des Frist-Gates.
- Geratene Opodo-`funnel=`- oder Booking-`cancel.html`-Templates ohne Fixture.
