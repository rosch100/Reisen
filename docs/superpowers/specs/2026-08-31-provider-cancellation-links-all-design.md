# Provider-Storno-Links: maximale Belegung (Hybrid)

Datum: 2026-08-31  
Status: Entwurf (brainstorming freigegeben)  
Plattformen: macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`, Private und Store)

## Ziel

Alle Sync-Provider unterstützen den Storno-Einstieg **so gut wie belegt möglich**:

1. **Distinct Storno-URL**, wenn HAR/Fixture/Live-Beleg einen buchungsspezifischen HTTPS-Pfad ≠ Öffnen-URL liefert.
2. **In-Page-Cancel**, wenn Storno nur auf der Buchungsseite (Modal/Button) liegt: `cancellationUrl` bewusst gleich `externalUrl`, Storno nur über **Session-Sheet**.
3. Sonst `nil` — kein Raten, kein Dummy-Template.

Reisen storniert nicht selbst. UI-Semantik (Fristen-Gate, destruktives „Stornieren“, Sheet) bleibt in [2026-08-30-in-app-cancellation-sheet-design.md](2026-08-30-in-app-cancellation-sheet-design.md). Pipeline-Grundlage: [2026-08-30-cancellation-portal-links-design.md](2026-08-30-cancellation-portal-links-design.md). Open-Matrix: [booking-portal-open.md](../../dev/booking-portal-open.md).

## Entscheidungen (Konsens)

| Thema | Wahl |
|-------|------|
| Strategie | Hybrid: echte Cancel-URLs **und** dokumentiertes In-Page |
| In-Page ohne Session | **Kein** Safari-Doppel-Open (HIG) |
| Persistenz In-Page | `cancellationUrl == externalUrl` bewusst setzen (Sheet-Spec), kein separates Cloud-Enum |
| Ableitung UI | URL + `cancel == open` + `hasSessionWebView` (bestehende Presentation) |
| Belegpflicht | Fixture/HAR/dokumentierter Live-Beleg; Capture nachziehen statt raten |

## Begriffe

| Begriff | Bedeutung |
|---------|-----------|
| **distinctURL** | `cancellationUrl` HTTPS und ≠ `externalUrl` nach `browserURL`-Filter |
| **inPageOnOpen** | Cancel-Fläche = Buchungsseite; Extract setzt `cancellationUrl` auf dieselbe HTTPS-Open-URL |
| **none** | `cancellationUrl == nil` bis Beleg existiert |
| **Policy-SSOT** | `ProviderCancellationLinkPolicy` — dokumentiert Mode pro Provider(+Buchungstyp); Extract implementiert, Views raten nicht |

Die ältere Portal-Links-Zeile „keine Kopie der Öffnen-URL“ gilt **nur** für unbelegte Provider (`none`). Bei dokumentiertem `inPageOnOpen` ist die Gleichheit Absicht, kein Dummy.

## Architektur

```text
ProviderCancellationLinkPolicy (Mode: distinct | inPage | none)
        │
Provider-Extract / Enrich
  → Facts.cancellationUrl
        │  distinct: Template/Extract-URL
        │  inPage:   externalUrl (nur wenn browserURL-tauglich)
        │  none:     nil
        ▼
Draft → Upsert (nil wischt persistierte URL nicht)
        ▼
Booking.cancellationUrl
  → isActionable(status, deadlinesForDisplay)
  → presentation:
        Session → sheet (auch wenn cancel == open)
        kein Session + cancel ≠ open → safari
        kein Session + cancel == open → hidden
  → ActionBar / Menü / Cancel-Sheet load(URL)
  → „Storno-Link kopieren“ nur wenn cancel ≠ open
```

Kein neues SwiftData-Attribut. Store-iOS ohne Hub-WebView: nur distinct+Safari; In-Page bleibt hidden.

## Provider-Matrix

| Provider | Mode | Beleg | Welle |
|----------|------|-------|-------|
| Traveloka | distinct | `TravelokaAPI.refundPresubmissionURL` | 0 (Ist) |
| Airbnb Experience | distinct | `experience_alteration/…?flow=oneCancel` | 0 (PR #98 / Ist) |
| billiger-mietwagen.de | distinct | Live `/reservation/cancellation` (SPA, keine Buchungs-ID im Pfad; Session) | 1 |
| GetYourGuide | inPage | HAR/Live: Cancel-Modal auf `/booking/{hash}` | 1 |
| Opodo | distinct | Hash `#tripdetails/…&funnel=cancellationHSA` (Fragment behalten) | 1, wenn Token/Open ableitbar |
| Booking.com Hotel | distinct | Live-Kandidat `cancel.html` | 1 nur mit Fixture-/Pfad-Beleg |
| Booking.com Flug | inPage oder none | oft Cancel auf Confirmation | 2 falls unsicher |
| Check24 | inPage oder none | oft Kundenbereich-Buchungsseite | 2 falls unsicher |
| Airbnb Stay | none bis Cancel-HAR | geratene `/reservation/cancel/{code}` = 404 | 2 |
| Manual | Editor-HTTPS = distinct | Nutzer | — |

**Welle 1 (dieser Spec-Scope):** Policy-SSOT + Docs/Matrix-Update + Extract/Tests für GYG (inPage), billiger-mietwagen (distinct), Opodo/Booking Hotel soweit ableitbar ohne Raten.  
**Welle 2:** Cancel-Click-HARs; Matrix und Extract nachziehen.

## Komponenten

| Stück | Verantwortung |
|-------|----------------|
| `ProviderCancellationLinkPolicy` | Mode + Kurzbegründung; SSOT für Docs/Tests |
| Provider-`*API` / Parser | URL bauen oder Open spiegeln laut Policy |
| `BookingPortalCancellation` | unveränderte Presentation-Regeln; `allowsCopyingCancellationLink(cancel:open:)` = `(cancel != nil && cancel != open)` |
| SharedUI ActionBar/Menü | Copy-Cancel nur wenn `allowsCopyingCancellationLink` |
| `docs/dev/booking-portal-open.md` | Storno-Matrix an diese Spec anbinden |

## Fehler und Grenzen

- Weder distinct `cancellationUrl` noch (bei inPage) browserURL-taugliche Open-URL → kein Storno-Control.
- Keine anzeigbare Frist → hidden (bestehendes Gate).
- Sheet-Nav-Fehler → Fehler im Sheet, kein stiller Safari-Wechsel.
- Paste-Import setzt `cancellationUrl` nicht.
- Kein DOM-Auto-Klick auf Portal-Cancel.
- Kein Provider-Cancel-API / lokales `cancelled` durch diesen Flow.

## Tests

- Domain: Presentation und Copy-Regel (distinct vs same-URL × Session).
- Welle 1 Provider: GYG `cancellationUrl == externalUrl` und actionable-Voraussetzungen; billiger-mietwagen Cancellation-Pfad ≠ Open; Opodo Fragment wenn ableitbar; Traveloka/Airbnb Experience Regression.
- Negativ: Airbnb Stay / unbelegte Cases bleiben `nil` bzw. explizit inPage nur mit Open-URL.
- Keine HAR-Binaries im Repo; nur redigierte Assertions.

## Akzeptanz

1. Policy-Matrix deckt alle `ProviderID.syncProviderIDs` ab (Mode ≠ stilles Vergessen).
2. GYG: bei Open-URL + anzeigbaren Fristen erscheint Stornieren nur mit Hub-Session (Sheet).
3. billiger-mietwagen: distinct Cancellation-URL; Sheet/Safari laut Presentation.
4. Kein Safari-Open für Stornieren, wenn URL identisch zur Öffnen-URL.
5. Copy-Storno-Link fehlt bei gleicher URL.
6. Welle-2-Provider dokumentiert als `none`/offen, nicht geraten.

## Nicht in Scope

- Neue Cancel-Click-HARs als Blocker für Welle 1 (nur wo Beleg schon existiert).
- Schema-Enum für Cancel-Mode.
- XCUI / automatisches Klicken im Portal.
- Änderung des Frist-Gates.
