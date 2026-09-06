# Design: Nach Zugangsdaten-Speichern automatisch ausfüllen und anmelden

**Datum:** 2026-09-06
**Status:** approved (feature-dev P1 Judge looks_good)
**p1_path:** promote
**Baut auf:** `docs/superpowers/specs/2026-07-17-provider-credential-autofill-design.md` (Ansatz 3: Keychain + JS-Fill+Submit). Keine neue Credential-Architektur.

## Problem

Nach „Anmeldung merken…“ gibt die Person Portal-Zugangsdaten ein und bestätigt mit **Speichern** (`action.save_credential`). Der nächste fachliche Schritt ist bereits implementiert: **Zugangsdaten ausfüllen** (`action.fill_credentials`) lädt das Konto und `ProviderLoginAssistance` füllt die Login-Felder und klickt Anmelden (Submit).

Heute muss dieser Schritt auf **macOS** extra geklickt werden: `SyncView` lädt nach `onSaved` das Konto ohne `autoFill: true`. **iOS** (`SyncTab`) plant nach Speichern bereits `scheduleAutoFillFromKeychain()`, aktualisiert die Kontoliste aber nicht über denselben Reload-Pfad.

Ziel: nach erfolgreichem Speichern eines Passwort-Kontos, solange die Session noch Login braucht, **sofort** denselben Fill+Submit-Pfad ausführen — ohne zweiten Klick.

## Ziele

1. Nach erfolgreichem Speichern (Passwort-Modus) und `needsLogin`: automatisch Fill+Submit.
2. macOS und iOS nutzen **dieselbe** Continue-Entscheidung und denselben Reload+Fill-Pfad.
3. Kein zweiter JS- oder Keychain-Fill-Pfad.
4. Button „Zugangsdaten ausfüllen“ bleibt als Retry sichtbar, sobald mindestens ein Konto existiert.

## Nicht-Ziele

- Browser-Entitlement / Safari-Passwords-Popover (Ansatz 1 der Parent-Spec).
- Auto-Fill bei `.sessionOnly` (Apple/Passkey/OAuth-Hinweis, kein Passwort).
- Auto-Fill wenn die Session bereits `.sessionReady` ist (Konto nur merken).
- Stilles Füllen bei mehreren Konten **ohne** gerade gespeicherte/explizite Auswahl (Parent-Spec bleibt).
- Live-Portal-E2E in CI (PII, fremde Sites).
- First-Launch-Provider-Setup (keine Portal-Passwort-Eingabe).
- Neue XCUI-Mutation (Speichern tippen würde Keychain schreiben / WebView anfassen).

## Entschiedener Ansatz (Gapfill, keine 2–3-Alternativen)

Parent-Spec bleibt SSOT für Speichern und Fill. Neu ist nur die **Orchestrierung nach Speichern**:

| Schritt | Verhalten |
| --- | --- |
| Speichern fehlgeschlagen | Sheet bleibt; kein Continue |
| Speichern ok, Modus `.sessionOnly` | kein Fill |
| Speichern ok, Session nicht `needsLogin` | Konto merken; kein Fill |
| Speichern ok, `needsLogin`, Passwort-Modus | Konto wählen + `autoFill: true` → bestehendes `KeychainAutoFill.applyAccount` → Fill+Submit |

iOS-`onSaved` wird auf denselben Reload-Pfad wie macOS gezogen (Preferred-ID aus der SSOT, dann `reloadKeychainAccounts(autoFill:)`), statt Fill an der Kontoliste vorbei zu planen.

### Verworfene Alternativen (nicht neu abstimmen)

- Sheet-Button in „Speichern und anmelden“ umbenennen: Extra-Copy, zwei Semantiken in einem Control; Continue ist die Folge von Speichern, nicht ein neuer Verbund-Button.
- WebView-Navigation auf die Login-URL als eigener Schritt: Fill+Submit-SSOT macht das bereits (Methoden-Klick, Retries).
- Nur macOS patchen ohne SSOT: iOS und macOS würden wieder divergieren.

## Begriffe (`spec_terms`)

| Begriff | Bedeutung |
| --- | --- |
| **LoginContinueAfterSave** | Orchestrator-Ergebnis: `preferredAccountID` + Fill ja/nein + `reason`. |
| **Post-Save-Continue** | Host nach `onSaved`: SSOT anwenden, Konten neu laden, bei ja `autoFill`. |
| **Fill+Submit-SSOT** | `KeychainAutoFill.applyAccount` → `ProviderLoginAssistance` (Felder + Anmelden-Klick). |
| **sessionOnly-Skip** | `.sessionOnly` → kein Fill. |
| **sessionReady-Skip** | Session nicht `needsLogin` → kein Fill. |

## SSOT

| Schicht | Datei | Rolle |
| --- | --- | --- |
| Orchestrator | `Sources/ReisenProviders/ProviderRememberLogin.swift` | `loginContinueAfterSave` + `applyAfterSavedAccount` (Preferred-ID setzen) |
| Fill+Submit | `Sources/ReisenProviders/KeychainAutoFill.swift` | unverändert als einziger Apply-Pfad |
| macOS-Host | `Sources/Reisen/App/SyncView.swift` | `onSaved` → Reload mit `autoFill` laut Entscheidung |
| iOS-Host | `Apps/ReiseniOS/ProviderSync/SyncTab.swift` | derselbe Reload+`autoFill`-Pfad |
| Sheet | `Sources/ReisenProviderSync/SaveProviderCredentialSheet.swift` | unverändert: Speichern, `onSaved`, dismiss |

## Entscheidung (testbarer Einstieg)

Beide Hosts rufen **dieselbe** Funktion. Tests belegen Preferred-ID **und** Fill-Flag — nicht nur den Bool-Port.

```swift
public struct LoginContinueAfterSave: Equatable, Sendable {
    public let preferredAccountID: String
    public let shouldAutoFill: Bool
    public let reason: String
}

public static func loginContinueAfterSave(
    account: KeychainCredentialAccount,
    sessionNeedsLogin: Bool,
    mode: ProviderRememberLoginMode
) -> LoginContinueAfterSave
```

| `sessionNeedsLogin` | `mode` | `preferredAccountID` | `shouldAutoFill` | `reason` |
| --- | --- | --- | --- | --- |
| true | `.passwordManual` / `.passwordPrefill` | `account.id` | true | `needs_login` |
| true | `.sessionOnly` | `account.id` | false | `session_only` |
| false | beliebig | `account.id` | false | `session_ready` |

Kein stiller Default: jeder Mode-Zweig ist exhaustiv. `preferredAccountID` ist immer `account.id` (explizite Auswahl nach Speichern).

## Host-Vertrag

Nach erfolgreichem `onSaved(account)`:

1. `let decision = applyAfterSavedAccount(account:sessionNeedsLogin:mode:setPreferredAccountID:)`
2. Preferred-Account-ID wird in der SSOT gesetzt (bestehende Persistenz des Hosts via Callback).
3. Konten neu laden mit `autoFill: decision.shouldAutoFill`:
   - macOS: `reloadKeychainAccounts(selecting: account, autoFill:)`
   - iOS: `reloadKeychainAccounts(autoFill:)` — wählt über `preferredKeychainAccountID()` / `KeychainAutoFill.pickAccount`
4. Bestehende Erfolgsmeldung `credentialSavedForHost` bleibt.
5. Fill-Fehler: bestehendes `keychainMessage` + Diagnostic; Button bleibt Retry.

iOS-`onSaved` darf Fill nicht mehr parallel über `scheduleAutoFillFromKeychain()` planen.

## Schnittstellen

`profiles: [live_app]` — kein `port-only`.

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| save-sheet-confirm | entry | Toolbar Speichern → `save()` → `onSaved` → `applyAfterSavedAccount` → Reload+`autoFill` | `applyAfterSavedAccount` setzt Preferred-ID; Tests auf ID + `shouldAutoFill`; Hosts ohne paralleles `scheduleAutoFillFromKeychain()` |
| continue-after-save | contract | `loginContinueAfterSave(account:sessionNeedsLogin:mode:)` | `ProviderRememberLoginTests` Entscheidungstabelle |
| fill-submit-ssot | neighbor | unverändert `KeychainAutoFill.applyAccount` | bestehende Tests; kein zweiter Fill-Pfad |
| live-app-isolation | capability | bestehende Prefs-Sites; kein neuer Store; Smoke schreibt nicht | Isolation-Tabelle unten + Plan-Grep 4 Muster / 5 Dateien |
| live-app-assert-vs-act | entry | Reach-only Remember-Login; kein Save/Fill-Tap | `MacUISmokeTests.testProviderSyncChromeIsReachable` |
| live-app-handler-trace | entry | Speichern-Handler wie Handler-Trace | P1/P2 Judge liest Sheet + Host-`onSaved` |
| live-app-identifiers | entry | `reisen.sync.remember-login`, `reisen.sync.fill-credentials` je einmal | `UITestingIdentifiersTests`; Smoke |
| live-app-sheet-window | entry | bestehendes Credential-Sheet; kein neues Fenster | Smoke öffnet Sheet nicht; Page Object unverändert |
| live-app-compile-units | capability | keine neue UI-Test-Datei; Imports unverändert | Diff ohne `Tests/ReisenMacUITests` außer unverändertem Smoke |
| live-app-process-hooks | capability | kein neuer Suite-Hook; `UITestingLaunch.isActive` bleibt Launch-Skip | Diff ohne `use(suite)` / neuen Prozess-Hook |
| keychain-capability | capability | bestehendes Keychain-Entitlement | kein Entitlement-Diff |

## Logging

| event | phase | result | reason |
| --- | --- | --- | --- |
| `credential_save_continue` | `keychain` | `started` | `needs_login` |
| `credential_save_continue` | `keychain` | `skipped` | `session_ready` / `session_only` |

Kein Username, kein Passwort, keine Account-ID. Fill-Fehler bleiben bei bestehenden `credential_load` / `login_autofill_failed` Events. Hosts loggen die Continue-Entscheidung (ein Event pro Speichern).

## UI / live_app

### Handler-Trace

1. Toolbar **Speichern** → `SaveProviderCredentialSheet.save()` → Keychain `save` → `onSaved` → `dismiss`.
2. Host `onSaved` → `applyAfterSavedAccount` (setzt Preferred-ID) → `reloadKeychainAccounts(..., autoFill:)` → `selectAccount` → `scheduleAutoFillFromKeychain` → `insertKeychainCredentials` → `KeychainAutoFill.applyAccount`.
3. Button **Zugangsdaten ausfüllen** bleibt derselbe `insertKeychainCredentials`-Handler (Retry).

Reach-only-Smoke darf Speichern **nicht** tippen (Keychain-Write + WebView-Fill).

### Isolation (vollständiger Grep, nicht Stichprobe)

Muster: `@AppStorage` / `AppStorage(`, `UserDefaults.standard`, `fromUserDefaults`, `supportDirectoryURL`.
Dateien: `SyncView.swift`, `SyncTab.swift`, `ProviderRememberLogin.swift`, `SaveProviderCredentialSheet.swift`, `KeychainAutoFill.swift`.

| Datei | Treffer | Vertrag |
| --- | --- | --- |
| `SyncView.swift` | `@AppStorage` Settings L20–33; `AppStorage(` Init ohne `store:` für `providerEnabled_*` und `preferredKeychainAccountID` L55–59 | bestehend; Continue schreibt nur den bestehenden Preferred-Key; Smoke tippt Speichern nicht |
| `SyncTab.swift` | `@AppStorage` `rememberLoginAutomatically` L50; `UserDefaults.standard` get/set Preferred-ID L331–339; `AppSettings.fromUserDefaults()` am Sync-Button L556 | bestehend; `setPreferredKeychainAccountID(decision.preferredAccountID)` bleibt der Ist-Write; Smoke schreibt nicht |
| `ProviderRememberLogin.swift` | keine | Orchestrator ist rein |
| `SaveProviderCredentialSheet.swift` | keine | unverändert |
| `KeychainAutoFill.swift` | keine | unverändert |
| alle fünf | `supportDirectoryURL` | keine Treffer |

Kein neuer Persistenz-Site. XCUI-Smoke öffnet das Sheet nicht und schreibt keinen Preferred-Key. `UITestingLaunch.isActive` in `SyncView.onAppear` überspringt Auto-Login beim Launch (bestehend).

### Identifier

Bestehend, unverändert, eindeutig:

- `reisen.sync.remember-login`
- `reisen.sync.fill-credentials`

Kein neues Fenster. Sheet bleibt dasselbe Scene-Sheet.

### Assert vs. Act

`MacUISmokeTests.testProviderSyncChromeIsReachable`: `waitFor` Remember-Login; Fill existiert nicht ohne Konto. Kein `tap` auf Speichern/Ausfüllen.

## Tests

- Unit: `loginContinueAfterSave(account:sessionNeedsLogin:mode:)` — Entscheidungstabelle inklusive `preferredAccountID == account.id`.
- Hosts: nur SSOT-Aufruf + Reload; iOS entfernt paralleles `scheduleAutoFillFromKeychain()` in `onSaved`.
- XCUI: bestehender Smoke unverändert (Reach-only). Live-Portal-Fill ist `open_gaps`, nicht Port-Ersatz.
- Kein Live-Portal-Corpus in CI.

## open_gaps

- Echtes Provider-Portal nach Speichern (manuell / Acceptance).
- iOS-XCUI-Target existiert nicht.
- First-Launch-Setup bleibt ohne Portal-Passwort.

## Akzeptanz

1. Speichern bei `needsLogin` + Passwort-Modus → Felder werden befüllt und Anmelden ausgelöst, ohne „Zugangsdaten ausfüllen“ zu klicken.
2. Speichern bei `.sessionOnly` oder Session bereit → kein Fill.
3. Fill-Fehler → Meldung, Retry-Button nutzbar.
4. Mehrere Konten: das gerade gespeicherte wird gewählt und gefüllt (explizite Auswahl).
5. macOS und iOS dasselbe Entscheidungsverhalten.
