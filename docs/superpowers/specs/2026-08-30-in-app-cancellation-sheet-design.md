# In-App-Storno: Sheet mit Provider-Session

Datum: 2026-08-30  
Status: Entwurf  
Plattformen: macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`, Private und Store)

## Ziel

1. **Stornieren** erscheint nur, wenn Storno für **diese** Buchung möglich ist: belegte Storno-URL, Status nicht cancelled, und mindestens eine **anzeigbare** Stornofrist (kostenlos oder Teil-Fee, nicht Vollpreis, nicht abgelaufen).
2. Der Tap öffnet den Portal-Storno-Flow **in der eingeloggten Provider-Session**: dieselbe Hub-`WKWebView` in einem Sheet. Das ist der zusätzliche Schritt (keine Settings, kein `confirmationDialog`).
3. Reisen storniert **nicht** selbst (kein Cancel-API, kein lokales `cancelled`). Schließen des Sheets ohne Portal-Abschluss ändert die Buchung nicht.

Voraussetzung: persistierte `cancellationUrl` und Extract-Matrix. **URL-Extract / Provider-Modes (SSOT):** [2026-08-31-provider-cancellation-links-all-design.md](2026-08-31-provider-cancellation-links-all-design.md) (ersetzt die v1-Matrix in [cancellation-portal-links-design.md](2026-08-30-cancellation-portal-links-design.md)). Diese Spec **ändert das Storno-Control** (Frist-Sichtbarkeit, Titel, destruktive Rolle, Session-Sheet).

Live-Belege (Browser 2026-08-30, nichts storniert): Traveloka Refund-Info mit „Start My Refund“; billiger-mietwagen scoped Cancel nur von Buchungsdetail (Assist B + Fallback A, Spec 2026-09-07); mehrere Provider stornieren **auf der Buchungsseite** (In-Page-Modal / Button), nicht auf einem eigenen GET-Pfad.

Verwandt: [booking-portal-open.md](../../dev/booking-portal-open.md), [booking-trip-delete-design.md](2026-08-28-booking-trip-delete-design.md).

## Ist-Zustand

| Stück | Verhalten |
|-------|-----------|
| Storno-Button | `Link` / `openURL`, Titel „Storno“, kein `.destructive`. `isActionable`: URL gesetzt, nicht cancelled; **gleiche URL wie Öffnen ist erlaubt**, wenn die Buchungsseite die Cancel-Fläche ist. |
| Fristen | `deadlinesForDisplay` blendet abgelaufene und Vollpreis-Paid aus. |
| Session | Eine Hub-`WKWebView` pro aktivem Sync-Provider. Sync funktioniert unabhängig von der sichtbaren Provider-Seite (Cookie-Fetch oder eigenes `load`). |
| Reparenting | Probe- und Sync-Host teilen die Instanz; `updateNSView` holt sie zurück, wenn `superview` nicht der Sync-Host ist. |
| Store-iOS | Keine Provider-WebViews. |

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---------|-----------|
| **Storno-URL** | `Booking.cancellationBrowserURL`. Darf der Öffnen-URL **gleichen**, wenn das Portal dort storniert (Matrix in der Portal-Links-Spec). |
| **Eigene Storno-Seite** | Storno-URL ≠ Öffnen-URL (Traveloka Refund, Airbnb, Check24 `?action=cancel`, Booking.com Hotel `cancel*.html`). |
| **Cancel-Fläche = Buchungsseite** | Storno-URL == Öffnen-URL: In-Page-Modal oder Button auf der Detailseite (GYG, billiger-mietwagen, Opodo; Booking.com Flug sofern belegt). |
| **Anzeigbare Frist** | `CancellationDeadlineDisplayFilter.deadlinesForDisplay` — Zukunft, Free oder Paid unter der höchsten gespeicherten Fee. Vollpreis-Paid und Paid ohne Betrag zählen nicht. |
| **Storno möglich** | `isActionable`: nicht cancelled, Storno-URL gesetzt, `deadlinesForDisplay` nicht leer. **Kein** Zwang `cancel ≠ open`. |
| **Stornieren-Button** | Titel „Stornieren“ (DE; EN-Key `action.cancel_in_portal`). `role: .destructive`. |
| **Cancel-Sheet** | Modal mit der Hub-WebView des Buchungs-`provider`; lädt die Storno-URL (Fragment bleibt, `URL(string:)`). |
| **Display-Owner** | `syncHost` \| `cancelSheet`. Solange Sheet: Probe- und Sync-Host betten nicht ein. |
| **Safari-Fallback** | `openURL` der Storno-URL **nur** wenn keine Hub-WebView **und** eigene Storno-Seite (`cancel ≠ open`). Bei gleicher URL wie Öffnen ohne WebView: **kein** Stornieren-Button (Öffnen reicht). |

## Anforderungen

### In Scope

- `isActionable(cancellation:open:status:deadlines:now:)` — Fristen zusätzlich; gleiche URL wie Öffnen bleibt actionable (Portal-Links-Kontrakt).
- Sichtbares Stornieren: `visible.cancel` **und** (Hub-WebView **oder** eigene Storno-Seite). Sonst kein Control, nicht disabled.
- Hub-WebView da: Sheet, Owner `cancelSheet`, `load` der Storno-URL. In-Page-Cancel passiert auf der geladenen Seite in der Session (Cookies).
- billiger-mietwagen: `cancellationUrl == externalUrl` (`inPageOnOpen`). Sheet lädt Buchungsdetail; Assist löst „Buchung stornieren“ aus → scoped Cancel-Formular; bei Misserfolg bleibt die Detailseite (manuell). Ohne Hub-WebView kein Stornieren-Button.
- Opodo: `cancellationUrl == externalUrl` (`inPageOnOpen`). Sheet lädt Trip-Detail; Assist öffnet Bestätigungsdialog („Buchung abbrechen“), **klickt nie** „Diese Buchung stornieren“.
- Traveloka: Seite ist Refund-Info („Start My Refund“); Sheet zeigt sie, Reisen klickt nicht weiter. Enrich muss die Refund-URL setzen, auch wenn der Refund-HTML-Fetch wegen vorhandener Fristen übersprungen wird (Extract-Spec / Traveloka-Provider — nicht still nur Katalog).
- Nach Dismiss: Owner `syncHost`, WebView zurück. URL nicht restaurieren. Sync während des Sheets auf derselben Instanz bleibt erlaubt (manuell).
- Nach Dismiss bei **erkannter Portal-Storno-Completion** (Heuristik): stiller Single-Provider-Sync — SSOT [2026-09-07-portal-cancel-success-provider-resync-design.md](2026-09-07-portal-cancel-success-provider-resync-design.md). Kein lokales `cancelled` ohne Sync-Ergebnis.
- Sheet-Navigation fehlgeschlagen: Fehler im Sheet, Button bleibt, kein stiller Safari-Wechsel.
- Hash-URLs (Opodo): Fragment nicht strippen.
- L10n DE+EN.

### Nicht in Scope

- Settings-Toggle.
- `confirmationDialog` vor dem Sheet.
- Provider-Cancel-API, Tombstones, lokales `cancelled` **ohne** Provider-Sync.
- Zweites WebView.
- DOM-Klick auf „Start My Refund“ / Modal-Buttons (Nutzer im Sheet).
- Neue URL-Extracts (Portal-Links-Spec). Kein `?? externalUrl` als Dummy, wenn Cancel unbelegt ist.
- XCUI.
- Auto-Sync ohne Completion-Heuristik; Safari-Storno ohne Sheet.

## Architektur

```text
Storno-URL + status + deadlinesForDisplay
        │
        ▼
isActionable  ──► visible.cancel
        │
        ├── nil / keine anzeigbare Frist → kein Control
        └── URL
              ├── hub.webView(provider) vorhanden
              │     → Sheet, load(Storno-URL)   // eigene Seite oder Buchungsseite+Modal
              ├── keine WebView und cancel ≠ open
              │     → openURL (Safari-Fallback)
              └── keine WebView und cancel == open
                    → kein Stornieren (Öffnen bleibt)
```

Schicht-Landung: Domain (Fristen in `isActionable` + Sichtbarkeit ohne WebView nur bei eigener Seite), AppCore (Display-Owner), SharedUI/Apps (destruktiver Button, Sheet, Hosts).

## HIG

- Kein Toggle; Sichtbarkeit ist die Gate.
- `.destructive` am Stornieren-Button.
- Sheet (bzw. Safari nur bei eigener Storno-Seite ohne Session) ist die Nachfrage.
- Zwei Buttons mit gleicher URL sind erlaubt, weil **unterschiedliche Präsentation**: Öffnen = System-Browser/AASA; Stornieren = Session-WebView (Modal/SPA braucht Login).
- Sheet-Dismiss: Abbrechen/Schließen, nicht noch einmal „Stornieren“.
- Symbol `arrow.up.right.square`.

## Fehler

| Fall | Verhalten |
|------|-----------|
| Keine anzeigbare Frist / cancelled / keine Storno-URL | kein Button |
| Cancel-Fläche = Buchungsseite, keine WebView | kein Stornieren |
| Eigene Storno-Seite, keine WebView | Safari-Fallback |
| Sheet-`load` fehlgeschlagen | Fehler im Sheet, kein Safari |
| Sync während Sheet | läuft; Seite darf weg navigieren |
| Store-iOS | wie „keine WebView“ |

## Tests

- Domain: Free-Frist + URL; abgelaufen; nur Vollpreis; Teil-Fee; Free+Vollpreis; Paid ohne Betrag ohne Free → aus; cancelled; `now` injiziert; **gleiche URL wie Öffnen bleibt actionable**.
- Sichtbarkeit ohne Hub: `cancel == open` → kein Stornieren; `cancel ≠ open` → Safari-Pfad.
- Hub-Owner: Sheet hält die View; nach Dismiss `syncHost`.
- Kein XCUI.

## Akzeptanz

1. Ohne anzeigbare Frist kein Stornieren, auch mit Storno-URL.
2. Traveloka (eigene Refund-URL) + Session: Sheet auf `refund/presubmission/…`, nicht Safari.
3. Cancel-Fläche = Buchungsseite + Session: Sheet lädt die Buchungsseite; Nutzer bedient Modal dort.
4. Dieselbe Situation ohne Session (Store-iOS): nur Öffnen, kein zweites Stornieren.
5. billiger-mietwagen: Sheet auf Buchungsdetail; Assist führt zum scoped Cancel-Formular oder belässt Detail (Fallback).
6. Sync während des Sheets möglich. Kein Settings, kein Confirm-Dialog, kein API-Storno.
7. Erkannte Portal-Storno-Completion → nach Dismiss stiller Provider-Sync ([Resync-Spec](2026-09-07-portal-cancel-success-provider-resync-design.md)).

## Risiken

| Risiko | Umgang |
|--------|--------|
| Sync-`load()` ersetzt Refund/Modal | akzeptiert |
| Host stiehlt die WebView | Display-Owner + Tests |
| Generic-URL ohne ID (BM) | ersetzt: Open-URL + Assist; Gast-Lookup nicht mehr Storno-Ziel |
| Hash-Cancel (Opodo) | Fragment in `browserURL` behalten |
| Portal-Links-Spec noch Link ohne destructive | diese Spec gilt für das Control |
