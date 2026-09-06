# Design: Passkey-Hinweis bei „Anmelden mit Apple“

**Datum:** 2026-09-06
**Status:** promote-and-gapfill (Cursor-Plan + bestehender Sync-Hinweis)
**Plattformen:** macOS (`Reisen`) und iOS/iPadOS (`ReiseniOS`)
**Profil:** `live_app`

## Herkunft

Vorlage (keine neue Architektur):

- Cursor-Plan `~/.cursor/plans/apple_passkey_webview_59710f8e.plan.md`
- Ist: `AuthIdentityProviderHost.showsApplePasskeyHint`, `SyncApplePasskeyHintLabel`, L10n `sync.apple_passkey_hint`
- Limitation: [docs/dev/traveloka-impl-spec.md](../../dev/traveloka-impl-spec.md) (Apple-ID-Passkey im eingebetteten Browser)

## Problem

Wenn ein Portal „Anmelden mit Apple“ / „Sign in with Apple“ öffnet, landet die Apple-ID-Seite oft in einem **Kind-`WKWebView`** (`ProviderAuthPopupPolicy.presentChild`). `didFinish`/`didCommit` kehren dort **ohne** Chrome-URL-Update zurück — bewusst, weil `ProviderSessionNavigation.handleDidFinish` sonst `hub.updateWebView` auf das Popup setzen würde.

Folge: `showsApplePasskeyHint` sieht nur die Parent-Portal-URL und bleibt `false`. Der bestehende Banner-Text spricht außerdem vom Apple-Passwort, nicht vom **Apple-Benutzernamen**, den die Apple-Seite zuerst verlangt.

## Ziel

Sobald „Anmelden mit Apple“ gewählt ist (Apple-IdP sichtbar, inkl. Auth-Popup), zeigt der Sync-Login-Chrome:

1. Passkey-Anmeldung funktioniert **in der App nicht**.
2. Der **Apple-Benutzername** muss eingegeben werden.

## Begriffe (SSOT)

| Begriff | Bedeutung |
| --- | --- |
| **Portal** | Buchungsquelle in Nutzer-Copy ([de-copy-clarity](2026-09-04-de-copy-clarity-design.md)); nicht „Provider“ |
| **Anmelden mit Apple** | Portal-OAuth über `appleid.apple.com` / `*.apple.com` in der Hub- oder Kind-WebView. Kein natives `ASAuthorizationAppleIDProvider`. |
| **Apple-IdP** | Host laut `AuthIdentityProviderHost.matchesApple` |
| **Auth-Popup** | Kind-`WKWebView` aus `createWebViewWith` (`presentChild`) |
| **Passkey-Hinweis** | Sync-Chrome-Text `sync.apple_passkey_hint`; kein Autofill, kein Fake-Klick |
| **Apple-Benutzername** | Apple-ID (E-Mail oder Telefon), die Apple auf der IdP-Seite zuerst verlangt |

## Anforderungen

### Sichtbarkeit

`AuthIdentityProviderHost.showsApplePasskeyHint` ist `true` genau dann, wenn:

- die Session `needsLogin` ist, **und**
- die **sichtbare** Auth-URL ein Apple-IdP ist: Parent-`lastURL` **oder** aktuelle Auth-Popup-URL.

Google/Facebook-IdP zeigen den Hinweis nicht.

`needsLogin == false` → kein Hinweis, auch auf Apple-Hosts.

### Copy (Key bleibt `sync.apple_passkey_hint`)

| Locale | Wert |
| --- | --- |
| de | Die Passkey-Anmeldung funktioniert in der App nicht. Gib den Apple-Benutzernamen ein. |
| en | Passkey sign-in does not work in the app. Enter your Apple username. |

Kein neues L10n-Key. Begriffe: **Passkey** (Apple-UI), **Apple-Benutzername**, **App** (nicht Safari-Exkurs, nicht „Kennwort“).

### Popup-URL ohne Hub-WebView-Tausch

Auth-Popup-Navigation veröffentlicht die Kind-URL **nur** für den Chrome-Hinweis (`authPopupURLAbsoluteString`).

Nicht:

- `hub.updateWebView` mit dem Kind
- Live-Probe / Autofill auf der Apple-Seite über den normalen `handleDidFinish`-Pfad
- Parent-`lastURL` dauerhaft auf Apple überschreiben (nach Dismiss bleibt Parent-URL)

Beim Schließen des Popups: Popup-URL zurücksetzen → Hinweis verschwindet, sobald kein Apple-IdP mehr sichtbar ist.

### Logging

Wenn der Hinweis von unsichtbar nach sichtbar wechselt:

- `component`: `SyncApplePasskeyHint`
- `phase`: `login`
- `event`: `apple_passkey_hint`
- `result`: `succeeded`
- `reason`: `apple_idp_visible`
- `visibility`: `publicDiagnostic`
- URL nur über Diagnostics-Redaction; kein Benutzername im Log

### Identifier / XCUI

- `UITestingIdentifiers.syncApplePasskeyHint` = `reisen.sync.apple-passkey-hint`
- Genau **ein** Element, nur solange der Hinweis sichtbar ist
- Smoke `testProviderSyncChromeIsReachable`: Check24-Login (kein Apple-IdP) → Identifier-Count **0** (Existence-only, kein Tap)

## Nicht-Ziele

- Passkey/WebAuthn in der `WKWebView` ermöglichen
- `ASWebAuthenticationSession` / Browser-Entitlement
- Natives Sign in with Apple nachbauen
- Hinweis im Storno-/Buchungs-Portal-Sheet (kein Login-Chrome; Folgespec)
- XCUI-Seed, der `appleid.apple.com` lädt oder den Hinweis erzwingt
- Autofill/Klick auf Passkey- oder IdP-Buttons (bestehende Scripts bleiben)

## Architektur

Bestehende Schichten:

| Stück | Schicht | Rolle |
| --- | --- | --- |
| `AuthIdentityProviderHost.showsApplePasskeyHint` | Providers | Vertrag: `needsLogin` + Parent-URL + optionale Popup-URL |
| `ProviderAuthPopupPolicy` | Providers | Kind bleibt; neue Chrome-URL-Hilfe nur wenn sie den Vertrag testbar macht |
| `SyncApplePasskeyHintLabel` | SharedUI | Text + Identifier |
| `SyncView` / `SyncTab` | Composition | Binding/Callback der Popup-URL; Log bei Sichtbar-Wechsel |
| `ProviderSessionView` / `WebViewHost` | Composition | Popup-URL setzen/löschen, **kein** `handleDidFinish` auf dem Kind |

## live_app (Ist-Code)

### Handler-Trace

Gelesene Produkt-Handler (nicht nur Page-Object):

| Schritt | Produkt-Handler | Side-Effect / Verbot |
| --- | --- | --- |
| Launch Populated | `UITestingLaunch` + `uiTestingIsolation()` → `defaultAppStorage(isolatedDefaults)`; `seedProviderEnablementIfNeeded` / `seedProviderSetupIfNeeded` | Suite `app.voyenna.reisen.uitesting`; CloudKit aus (`REISEN_CLOUDKIT=0`). Kein Nutzer-Store. |
| Sync Check24 | `MacUI.openProviderSyncCheck24` → `providerRow("check24").click()` → `SyncView` | Navigation. Unter `-UITesting`: `SyncView.body` rendert `loginChrome` + `Color.clear` (`syncProviderWebView`); `onAppear` **return** — kein `restoreSessionFromHub`, kein Keychain, kein Live-WebView. |
| Disclosure | `SyncView.providerLoginDisclosure(isActive:)` → Alert; Accept ruft `ProviderLoginDisclosure.accept()` → `UserDefaults.standard` | Smoke **tappt Accept nicht** (Reach-only). |
| Hinweis-Count 0 | `descendants.matching(identifier: syncApplePasskeyHint)` | **kein** Tap, kein Portal-Login, kein Extract. |
| Auth-Popup (Produkt, nicht XCUI) | `handleAuthPopupNavigation` setzt/löscht Popup-URL; `dismissAuthPopup` nil. `didFinish`/`didCommit` Early-Return **ohne** `updateSession` / `onDidFinish` | **Verboten** auf dem Kind: `ProviderSessionNavigation.handleDidFinish` → `hub.updateWebView`, Live-Probe, Autofill. |

Kein neuer mutierender Control. XOR `loginChrome` / `sessionBanner` bleibt — Hinweis höchstens einmal.

### Isolation-Grep (vollständig, 2026-09-06 Worktree `origin/master`)

Befehl (Worktree-Root):

```text
rg -n '@AppStorage|AppStorage\(|UserDefaults\.standard|fromUserDefaults|supportDirectoryURL' \
  Sources/ReisenProviders/AuthIdentityProviderHost.swift \
  Sources/ReisenSharedUI/SyncApplePasskeyHintLabel.swift \
  Sources/Reisen/App/SyncView.swift \
  Sources/Reisen/Platform/ProviderSessionView.swift \
  Apps/ReiseniOS/ProviderSync/SyncTab.swift \
  Apps/ReiseniOS/ProviderSync/WebViewHost.swift \
  Sources/ReisenSharedUI/ProviderLoginDisclosureModifier.swift \
  Sources/ReisenDomain/Settings/ProviderLoginDisclosure.swift \
  Sources/ReisenSharedUI/UITestingIsolation.swift \
  Sources/ReisenAppCore/UITestingLaunch.swift \
  Sources/Reisen/Reisen.swift
```

Ist-Output (kein Sample):

| Datei:Zeile | Treffer | Isolation |
| --- | --- | --- |
| `SyncView.swift`:20–31 | 12× `@AppStorage(AppSettingsKeys…)` ohne `store:` | XCUI: `Reisen.swift` `.uiTestingIsolation()` → `defaultAppStorage(UITestingLaunch.isolatedDefaults)` |
| `SyncView.swift`:32–33, 55–62 | `@AppStorage` / `AppStorage(wrappedValue:key:)` Provider-Enable + Keychain-Account, ohne `store:` | dieselbe Suite |
| `SyncTab.swift`:50 | `@AppStorage(rememberLoginAutomatically)` | iOS XCUI analog Isolation-Modifier; dieses Feature tappt Sync nicht |
| `SyncTab.swift`:310–318 | `UserDefaults.standard` get/set preferred Keychain-Account | bestehend; Hint-Pfad liest das nicht; kein neuer Call |
| `SyncTab.swift`:535 | `AppSettings.fromUserDefaults()` im Sync-Button | Smoke tappt Sync-Button nicht |
| `ProviderLoginDisclosureModifier.swift`:5 | `@AppStorage(accepted)` ohne `store:` | XCUI → isolatedDefaults |
| `ProviderLoginDisclosure.swift`:43–48 | `isAccepted`/`accept` Default `.standard` | Smoke tappt Accept **nicht**. Feature ändert die API nicht. |
| `UITestingLaunch.swift`:104 | `isolatedDefaults` | gewollte Suite, `removePersistentDomain` |
| `AuthIdentityProviderHost`, `SyncApplePasskeyHintLabel`, `ProviderSessionView`, `WebViewHost` | keine Treffer | — |

`supportDirectoryURL` (Test-Host, nicht in den sechs Feature-Dateien): `PersistenceBootstrap+StoreURLs`, `GitHubIssueCrashCatcher`, `GitHubIssueReporter`, `RuntimeEnvironmentSnapshot`. Feature rührt sie nicht; XCUI-Launch ändert Crash-Catcher nicht.

**Diff-Pflicht:** keine neuen `@AppStorage` / `UserDefaults.standard` / `fromUserDefaults` / `supportDirectoryURL`. Inner wiederholt denselben `rg` auf den angefassten Dateien; neuer Treffer = Blocking.

### Identifier / Assert vs. Act / Fenster

Eine ID, nur am Hinweis-Label. Query im Main-Window der Sync-Fläche (kein Extra-Fenster, kein Settings-Sheet). UI-Test-Target: bestehende Imports (`XCTest`, `ReisenAppCore`, `ReisenData`, `ReisenSharedUI` — Identifier-Konstanten); kein neuer SharedUI-View-Import.

## Schnittstellen

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| apple-hint-contract | contract | `showsApplePasskeyHint(needsLogin:urlAbsoluteString:authPopupURLAbsoluteString:)` | `AuthPageURLHeuristicTests` |
| apple-hint-copy | contract | L10n `sync.apple_passkey_hint` | `L10nTests` Assert auf DE/EN-Wortlaut |
| apple-hint-entry | entry | Sync-Login-Chrome (macOS + iOS) zeigt `SyncApplePasskeyHintLabel` | Identifier + Unit; XCUI nur Negativ (kein Apple) |
| apple-hint-popup | neighbor | Popup-URL-Binding/Callback, kein `updateWebView` | Policy-/Host-Unit; Code-Review der Delegate-Returns |
| apple-hint-log | contract | Diagnostic bei Sichtbar-Wechsel | Event-Felder im Diff; bestehendes Logger-Muster |
| live-app-isolation | capability | keine neuen Defaults-Sites | Isolation-Grep Diff |
| live-app-assert-vs-act | entry | Smoke Count 0, kein Tap | `testProviderSyncChromeIsReachable` |

## Restlücken (bewusst)

- Storno-Sheet ohne Login-Chrome
- XCUI kann Apple-IdP nicht live ansteuern
- Passkey bleibt in der App ununterstützt

## DoD

Unit-Vertrag (Parent, Popup, Google, `needsLogin false`) grün; Copy-Assert; Identifier verdrahtet; Log-Event; `ci-test.sh`; XCUI-Diff inkl. Negativ-Assert.
