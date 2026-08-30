# In-App-Storno: Sheet mit Provider-Session

Datum: 2026-08-30  
Status: P1 (Promote-and-Gapfill)  
Plattformen: macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`, Private und Store)

## Ziel

1. **Stornieren** erscheint nur, wenn Storno für **diese** Buchung möglich ist: belegte Storno-URL, Status nicht cancelled, und mindestens eine **anzeigbare** Stornofrist (kostenlos oder Teil-Fee, nicht Vollpreis, nicht abgelaufen).
2. Der Tap öffnet den Portal-Storno-Flow **in der eingeloggten Provider-Session**: dieselbe Hub-`WKWebView` in einem Sheet. Das ist der zusätzliche Schritt (keine Settings, kein `confirmationDialog`).
3. Reisen storniert **nicht** selbst (kein Cancel-API, kein lokales `cancelled`). Schließen des Sheets ohne Portal-Abschluss ändert die Buchung nicht.

Voraussetzung: persistierte `cancellationUrl` und Extract-Matrix aus [cancellation-portal-links-design.md](2026-08-30-cancellation-portal-links-design.md) (auf `origin/master` via PR #83). Diese Spec **ändert das Storno-Control** (Frist-Sichtbarkeit, Titel, destruktive Rolle, Session-Sheet). URL-Extract bleibt dort.

Live-Belege (Browser 2026-08-30, nichts storniert): Traveloka Refund-Info mit „Start My Refund“; billiger-mietwagen SPA `/reservation/cancellation` ohne Buchungs-ID in der URL; mehrere Provider stornieren **auf der Buchungsseite** (In-Page-Modal / Button), nicht auf einem eigenen GET-Pfad.

Verwandt: [booking-portal-open.md](../../dev/booking-portal-open.md), [booking-trip-delete-design.md](2026-08-28-booking-trip-delete-design.md).

## Ist-Zustand (`origin/master` 5b94e47)

| Stück | Verhalten |
|-------|-----------|
| Storno-Button | `Link` / `openURL`, Titel DE „Storno“ (`action.cancel_in_portal`), kein `.destructive`. |
| `isActionable` | URL gesetzt, nicht cancelled, **und** `cancellation != open`. Gleiche URL wie Öffnen → kein Storno-Control. |
| Fristen | `deadlinesForDisplay` blendet abgelaufene und Vollpreis-Paid aus. **Nicht** in `isActionable`. |
| Session | Eine Hub-`WKWebView` pro aktivem Sync-Provider (`ProviderSessionHub`). Sync unabhängig von der sichtbaren Seite. |
| Reparenting | macOS `ProviderWebView.updateNSView` **stiehlt** die Hub-Instanz, wenn `superview !== host` (`resolveWebView` wiederverwendet `webViewRef`). iOS ist **nicht** analog: `makeUIView` erzeugt immer eine **neue** `InteractiveWKWebView`; `updateUIView` lädt nur `loginURL` und bettet nicht neu ein. `WebViewHostUIView.embed` kann stehlen, wird aber nur beim Create aufgerufen. Kein Display-Owner. |
| Store-iOS | Keine Provider-WebViews (Binary-Isolation). |
| Command | `ReisenCommands` ruft `openURL` auf der Storno-URL auf (`canCancel` = altes `isActionable`). |

Diese Spec **hebt** `cancel ≠ open` als Actionable-Zwang auf und **führt** Fristen + Session-Sheet ein. Die Portal-Links-Spec bleibt SSOT für Extract; ihr Satz „Button nur bei anderer URL“ gilt nicht mehr für das Control.

## Begriffe (SSOT)

| Begriff | Bedeutung |
|---------|-----------|
| **Storno-URL** | `Booking.cancellationBrowserURL`. Darf der Öffnen-URL **gleichen**, wenn das Portal dort storniert (Matrix in der Portal-Links-Spec). |
| **Eigene Storno-Seite** | Storno-URL ≠ Öffnen-URL (Traveloka Refund, Airbnb Experience, Booking.com Hotel `cancel.html`, billiger-mietwagen `/reservation/cancellation`, Opodo-Hash mit `funnel=cancellationHSA`). |
| **Cancel-Fläche = Buchungsseite** | Storno-URL == Öffnen-URL: In-Page-Modal oder Button auf der Detailseite (GYG, Check24, Booking.com Flug, Airbnb Stay sofern belegt). |
| **Anzeigbare Frist** | `CancellationDeadlineDisplayFilter.deadlinesForDisplay` — Zukunft, Free oder Paid unter der höchsten gespeicherten Fee. Vollpreis-Paid und Paid ohne Betrag zählen nicht. |
| **Storno möglich** | `isActionable`: nicht cancelled, Storno-URL gesetzt, `deadlinesForDisplay` nicht leer. **Kein** Zwang `cancel ≠ open`. |
| **Stornieren-Button** | Titel „Stornieren“ (DE; EN-Key `action.cancel_in_portal` bleibt, EN-Text „Cancel in portal“). `role: .destructive`. |
| **Cancel-Sheet** | Modal mit der Hub-WebView des Buchungs-`provider`; lädt die Storno-URL (Fragment bleibt, `URL(string:)`). |
| **Display-Owner** | `syncHost` \| `cancelSheet`. Solange Sheet: Probe- und Sync-Host betten **nicht** ein (`allowsEmbed == false`). |
| **Safari-Fallback** | `openURL` der Storno-URL **nur** wenn keine Hub-WebView **und** eigene Storno-Seite (`cancel ≠ open`). Bei gleicher URL wie Öffnen ohne WebView: **kein** Stornieren-Button (Öffnen reicht). |
| **hasSessionWebView** | `Bool` aus `ProviderSessionHub.webView(for: provider) != nil`. Domain kennt kein WebKit. |

## Anforderungen

### In Scope

- `isActionable(cancellation:open:status:deadlines:now:)` — Fristen zusätzlich; gleiche URL wie Öffnen bleibt actionable (Portal-Links-Kontrakt dieser Spec).
- `BookingPortalCancelPresentation`: `sheet` \| `safari` \| `hidden`. Sichtbares Stornieren nur bei `sheet` oder `safari`.
- Sichtbares Stornieren: `isActionable` **und** (Hub-WebView **oder** eigene Storno-Seite). Sonst kein Control, nicht disabled.
- Hub-WebView da: Sheet, Owner `cancelSheet`, `load` der Storno-URL. In-Page-Cancel passiert auf der geladenen Seite in der Session (Cookies).
- billiger-mietwagen: URL ohne Buchungs-ID ist Absicht; die SPA nutzt die Session. Sheet lädt genau diese URL, kein Erraten einer UUID in den Pfad.
- Traveloka: Seite ist Refund-Info („Start My Refund“); Sheet zeigt sie, Reisen klickt nicht weiter. Extract der Refund-URL bleibt Portal-Links-Spec.
- Nach Dismiss: Owner `syncHost`, WebView zurück. URL nicht restaurieren. Sync während des Sheets auf derselben Instanz.
- Sheet-Navigation fehlgeschlagen: Fehler **im Sheet**, Button bleibt, kein stiller Safari-Wechsel.
- Hash-URLs (Opodo): Fragment nicht strippen (`BookingExternalURL.browserURL` / `URL(string:)`).
- L10n DE+EN. Sheet-Dismiss: bestehendes `common.cancel` („Abbrechen“ / „Cancel“), nicht noch einmal „Stornieren“.
- Alle bisherigen Einstiege nutzen dieselbe Presentation-SSOT: ActionBar (macOS Inspector, iOS Detail), Kontextmenü (`ContentView`, `TripDetailView`, `OffenTab`, `TripDetailIOS`), macOS-Command. `BookingPortalCancelMenuButton` intern **kein** `openURL` bei `.sheet`.

### Nicht in Scope

- Settings-Toggle.
- `confirmationDialog` vor dem Sheet.
- Provider-Cancel-API, Tombstones, lokales `cancelled`.
- Zweites WebView.
- DOM-Klick auf „Start My Refund“ / Modal-Buttons (Nutzer im Sheet).
- Neue URL-Extracts (Portal-Links-Spec). Kein `?? externalUrl` als Dummy, wenn Cancel unbelegt ist.
- XCUI / UI-Test-Target / Harness.
- Neue Entitlements oder `LSApplicationQueriesSchemes`.

## Architektur

```text
Storno-URL + status + deadlinesForDisplay + hasSessionWebView
        │
        ▼
isActionable  ──► presentation
        │
        ├── hidden (nil / keine anzeigbare Frist / keine WebView und cancel == open)
        ├── sheet  (Hub-WebView vorhanden)
        └── safari (keine WebView und cancel ≠ open)
              │
              ├── sheet  → Owner cancelSheet, load(Storno-URL)
              └── safari → openURL
```

Schicht-Landung:

| Was | Wo |
|----|-----|
| `isActionable`, `BookingPortalCancelPresentation`, `visible` | `ReisenDomain` (Foundation; `hasSessionWebView: Bool`) |
| Display-Owner, Embed-Policy | `ReisenAppCore` (`ProviderSessionHub` + `ProviderWebViewDisplayPolicy`) |
| Destruktiver Button, Sheet-Chrome, Presentation-Callback | `ReisenSharedUI` |
| Hosts + Sheet-Einbettung + Command | `Reisen` (macOS `ProviderSessionView`); `Apps/ReiseniOS` (`WebViewHost` in `SyncTab` + `GlobalChrome`-Probe). iOS muss **dieselbe** Hub-Instanz resolven wie macOS — kein zweites WKWebView. |

Domain bleibt SwiftData-/WebKit-frei. Kein neues Modul. Kein zweites WKWebView.

### Display-Owner (Ist-Code)

macOS `ProviderWebView.updateNSView` stiehlt die Hub-Instanz, sobald `superview !== host`. Ohne Owner holt der Sync-/Probe-Host die View während des Sheets zurück.

iOS **heute**: kein Steal-back. `makeUIView` baut immer eine neue WebView. `SyncTab` hält `@State webView`; `SyncBackgroundSessionProbe` (`GlobalChrome`) hält `webViewsByProvider` **lokal** und schreibt nicht in den Hub (macOS `SyncView` / `ProviderSessionProbeHost` binden `get/set` an `hub.webView` / `updateWebView`).

Damit das Sheet nicht ein **zweites** WKWebView erzeugt: iOS-Bindings auf den Hub legen; `resolveWebView` zuerst Binding, dann `hub.webView(for:)`, erst dann `makeWebView`; `embed` in `makeUIView` **und** `updateUIView`; Steal nur bei `allowsEmbed`; nach Dismiss Steal-back zum Sync-Host.

Policy-SSOT (`ReisenAppCore`):

```text
allowsEmbed(owner:host:)
  syncHost    → probe | sync
  cancelSheet → cancelSheet
```

Hosts bekommen `allowsEmbed` **ohne** `?? true` (kein Hub → nicht einbetten). `updateNSView` / `updateUIView` dürfen bei `false` **nicht** einbetten.

### Sheet-Load

Cancel-Host lädt **nur** die Storno-URL (kein `loginURL`-Pfad von `ProviderSessionView`). `didFail` / `didFailProvisionalNavigation` → Fehlertext im Sheet. Kein `openURL`. Dismiss setzt Owner `syncHost`; vorherige Portal-URL wird nicht restauriert.

## HIG

- Kein Toggle; Sichtbarkeit ist die Gate.
- `.destructive` am Stornieren-Button.
- Sheet (bzw. Safari nur bei eigener Storno-Seite ohne Session) ist die Nachfrage.
- Zwei Buttons mit gleicher URL sind erlaubt, weil **unterschiedliche Präsentation**: Öffnen = System-Browser/AASA; Stornieren = Session-WebView (Modal/SPA braucht Login).
- Sheet-Dismiss: Abbrechen (`common.cancel`), nicht noch einmal „Stornieren“.
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

## Schnittstellen

Kein `port-only`. Kein Profil `unstructured_input` / `live_app` (kein XCUI, kein Paste/Extract).

| id | kind | Supply | Evidence |
|----|------|--------|----------|
| stornieren-entry | entry | ActionBar (`BookingDetailContent`, `BookingDetailIOS`); Kontextmenü (`ContentView`, `TripDetailView`, `OffenTab`, `TripDetailIOS`); macOS-Command | Domain presentation-Tests; SharedUI role/title; nach Inner sichtbarer Weg (verification-before-completion, kein XCUI) |
| session-webview-adapter | adapter | `hub.webView(for:)` an jedem Einstieg + Cancel-Host; fehlend ist typisiert `safari`/`hidden`, kein Crash, kein stiller Safari bei gleicher URL | Domain-Tests `hasSessionWebView` × URL-Gleichheit; Hosts reichen den Bool durch (kein Default `false` nach Task 4) |
| isActionable-contract | contract | Fristen + Status + URL; gleiche URL bleibt actionable | `BookingPortalCancellationTests` |
| display-owner-neighbor | neighbor | bestehender Hub; macOS `updateNSView`-Steal + iOS `resolveWebView`/`embed` in make+update; Probe (`GlobalChrome`) / Sync (`SyncTab`) stehlen nicht während `cancelSheet` | `ProviderWebViewDisplayPolicyTests` + Host-`allowsEmbed`-Verdrahtung |
| hash-url-neighbor | neighbor | `BookingExternalURL.browserURL` behält Fragment | Domain-Test Opodo-Hash |

Keine neue Capability. Store-iOS-Isolation bleibt bestehendes Binary-Gate.

## Tests

- Domain: Free-Frist + URL; abgelaufen; nur Vollpreis; Teil-Fee; Free+Vollpreis; Paid ohne Betrag ohne Free → aus; cancelled; `now` injiziert; **gleiche URL wie Öffnen bleibt actionable**.
- Presentation: Hub an + gleiche URL → `sheet`; Hub aus + gleiche URL → `hidden`; Hub aus + eigene Seite → `safari`.
- Hash-URL: Fragment bleibt in `cancellationBrowserURL`.
- Display-Owner: `allowsEmbed` für alle Owner×Host-Paare; nach Dismiss `syncHost`.
- L10n: DE-Button „Stornieren“, Key `action.cancel_in_portal`.
- Kein XCUI.

## Akzeptanz

1. Ohne anzeigbare Frist kein Stornieren, auch mit Storno-URL.
2. Traveloka (eigene Refund-URL) + Session: Sheet auf `refund/presubmission/…`, nicht Safari.
3. Cancel-Fläche = Buchungsseite + Session: Sheet lädt die Buchungsseite; Nutzer bedient Modal dort.
4. Dieselbe Situation ohne Session (Store-iOS): nur Öffnen, kein zweites Stornieren.
5. billiger-mietwagen: Sheet auf `/reservation/cancellation` (keine ID im Pfad).
6. Sync während des Sheets möglich. Kein Settings, kein Confirm-Dialog, kein API-Storno.

## Risiken

| Risiko | Umgang |
|--------|--------|
| Sync-`load()` ersetzt Refund/Modal | akzeptiert |
| Host stiehlt die WebView | Display-Owner + Tests |
| Generic-URL ohne ID (BM) | Session-SPA; nicht UUID in den Pfad raten |
| Hash-Cancel (Opodo) | Fragment in `browserURL` behalten |
| Portal-Links-Spec noch Link ohne destructive | diese Spec gilt für das Control |

## Offene Lücken (`open_gaps`)

- URL-Extract (Traveloka Refund immer setzen, übrige Provider-Matrix) — Portal-Links-Spec / anderer Worktree, nicht v1-Bug dieser Spec.
- DOM-Klick / XCUI / Live-Portal.
- Provider-Cancel-API.
