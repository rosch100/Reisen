# Design: Anmeldung merken — Password AutoFill statt Button „Passwörter öffnen“

**Datum:** 2026-09-06
**Status:** approved (feature-dev full_auto; Promote der Sheet-Architektur aus [provider-credential-autofill](2026-07-17-provider-credential-autofill-design.md))
**Vorgänger:** Ansatz 3 (Keychain + Sheet) bleibt. Diese Spec ändert nur den **manuellen Eingabe-Weg** im Dialog.

## Problem

Im Dialog **Anmeldung merken** (`SaveProviderCredentialSheet`, Modus `passwordManual`) steht ein Button **Passwörter öffnen**, der die System-App startet. Das ist überflüssig: Fokussiert man das **Passwort**-Feld, bietet macOS das Passwörter-Popover bereits an. Im **E-Mail-/Benutzername**-Feld fehlt dieses Angebot, weil das Feld für Password AutoFill nicht als Credential-Feld markiert ist.

## Ziele

1. Button **Passwörter öffnen** aus dem Dialog **Anmeldung merken** entfernen (inkl. Callback `onOpenPasswordManager`).
2. Username- und Passwort-Feld so markieren, dass das System-Passwörter-Angebot **in beiden** Feldern zuverlässig erscheint — laut Apple-Dokumentation, nicht per Heuristik-Zufall.
3. Bestehenden Keychain-Speicher-/Ausfüllen-Pfad (Ansatz 3) unverändert lassen.

## Nicht-Ziele

- Button **Passwörter öffnen** in der Sync-Login-Chrome (`SyncView.keychainAssistanceActionButtons`, Identifier `reisen.sync.open-passwords`) — bleibt.
- Associated Domains / `webcredentials:` / Browser-Entitlement (Ansatz 1 der July-Spec) — weiter defer.
- WKWebView-AutoFill für Fremd-Domains.
- L10n-Key-Renames; `action.open_passwords` bleibt für die Chrome.
- Footer-Copy umschreiben (optional später).
- iOS-XCUI-Target.

## Apple-Vertrag (SSOT)

Quelle: [Enabling Password AutoFill on a text input view](https://developer.apple.com/documentation/security/enabling-password-autofill-on-a-text-input-view); macOS: WWDC20 *AutoFill everywhere* (`NSTextContentType`).

| Feld | Pflicht | Nicht verwenden | Warum |
| --- | --- | --- | --- |
| E-Mail / Benutzername | `textContentType(.username)` | `.emailAddress` | `.emailAddress` ist Contacts-AutoFill, kein Password-AutoFill. Apple: bei E-Mail-as-Username **Content-Type `username`** und auf iOS zusätzlich `keyboardType = .emailAddress`. |
| Passwort (bestehendes Konto) | `textContentType(.password)` | `.newPassword` | `.newPassword` ist Konto-Anlage / Strong Password, unterdrückt gespeicherte Logins. |
| Lage | beide Felder **in derselben View** | getrennte Seiten ohne explizite Types | Heuristik erwartet Username+Passwort auf einer Seite; explizite Types machen die Heuristik robust. |

Weitere Apple-Hinweise, die wir übernehmen:

- Explizite Types verbessern die Heuristik und decken Flows ab, die sonst nicht erkannt werden. Das erklärt den Ist-Zustand: `SecureField` wird als Passwort erkannt (`NSSecureTextField` / `isSecureTextEntry`), das unmarkierte `TextField` nicht.
- iOS: Username zusätzlich `.textInputAutocapitalization(.never)`, `.autocorrectionDisabled()`, `.keyboardType(.emailAddress)`.
- Associated Domains (`webcredentials:`) verknüpfen die App mit **einer eigenen** Website für automatische Vorschläge und `SecAddSharedWebCredential`. Für fremde Portale (Booking, Check24, …) nicht verfügbar — July-Spec. Das **Passwörter-Popover** an getaggten nativen Feldern erscheint trotzdem; der Nutzer wählt den Eintrag. Kein neues Entitlement.

SwiftUI: `.textContentType(.username)` / `.textContentType(.password)` — auf beiden Plattformen gültig (iOS `UITextContentType`, macOS `NSTextContentType`). Die SSOT-Typen in `ProviderRememberLoginAutoFill` sind per `#if os(iOS)` / `#else` an das jeweilige SDK gebunden, nicht AppKit-only.

## Ist-Code

| Stelle | Heute | Soll |
| --- | --- | --- |
| `SaveProviderCredentialSheet` Username-`TextField` | keine Content-Type; iOS nur Autocap/Autocorrect off | `.username` + iOS Keyboard E-Mail |
| `SaveProviderCredentialSheet` `SecureField` | keine Content-Type (Heuristik reicht oft) | explizit `.password` |
| Sheet-Button `onOpenPasswordManager` | macOS `SyncView` übergibt `MacSystemApps.openPasswords()`; iOS nicht | API und Button entfernen |
| Sync-Chrome `keychainAssistanceActionButtons` | Button mit `syncOpenPasswords` | unverändert |

Handler **Anmeldung merken** (Reach vs. Act):

- macOS: `SyncView.openRememberLoginSheet()` → `ProviderRememberLogin.beginSheet` (nur In-Memory-Modus/Message) + `isSaveCredentialSheetPresented = true`.
- iOS: analog `showCredentialSheet = true`.
- Speichern (`save()` → `KeychainCredentialStore.save`) nur über den Bestätigen-Button. Smoke **tippt Speichern nicht**.

## Architektur

| Komponente | Rolle |
| --- | --- |
| `ProviderRememberLoginAutoFill` (`ReisenProviderSync`) | SSOT der Content-Types (`.username` / `.password`) |
| `SaveProviderCredentialSheet` | wendet SSOT an; kein Open-Passwords-Callback |
| `UITestingIdentifiers` | Sheet- und Feld-IDs; Chrome-`syncOpenPasswords` unberührt |
| `SyncView` / `SyncTab` | Sheet ohne `onOpenPasswordManager` |

`ReisenProviderSync` bekommt die bestehende Abhängigkeit `ReisenSharedUI` nur für Identifier — kein zweiter ID-String.

Logging: **entbehrlich**. Kein neuer I/O-/Sync-Pfad; nur Modifier und entfernte Hilfsaktion.

## Schnittstellen-Inventar

Profil: `live_app`. Nicht `port-only`.

| id | kind | supply | evidence |
| --- | --- | --- | --- |
| remember-login-sheet-entry | entry | macOS `SyncView.openRememberLoginSheet()` (Z. 758–766) und iOS `SyncTab.openRememberLoginSheet()` → `ProviderRememberLogin.beginSheet` (In-Memory) + Sheet präsentieren. Smoke tippt nicht Speichern. | `MacUI.openRememberLoginSheet` + Existence Sheet/Felder |
| autofill-content-types | contract | `ProviderRememberLoginAutoFill`: iOS `UITextContentType.username/password`, macOS `NSTextContentType.username/password` | `ProviderRememberLoginAutoFillTests` |
| no-associated-domains | capability | Keine neuen `webcredentials:` / Associated-Domains / Browser-Entitlement | Entitlement-Grep im Diff; Spec `open_gaps` |
| chrome-open-passwords-neighbor | neighbor | `SyncView.keychainAssistanceActionButtons` + `reisen.sync.open-passwords` unverändert | Identifier-Test + Chrome-Code unangetastet |
| keychain-save-neighbor | neighbor | `KeychainCredentialStore.save` nur über Sheet-Bestätigen; Journey ruft `onSaved` nicht | Smoke ohne Save-Tap |
| live-app-isolation | capability | Kein neuer `@AppStorage` / `UserDefaults.standard` / `supportDirectoryURL`. Bestehende Hits (unten) sind Launch-Reads; Journey mutiert sie nicht. | Isolation-Grep unten + Diff-Regression |
| live-app-assert-vs-act | entry | Klick „Anmeldung merken“ zeigt Sheet; Felder/fehlender Button nur `waitForExistence` / `exists`; kein Speichern, kein Chrome-Passwörter-Button | `testRememberLoginSheetHasAutofillFieldsWithoutOpenPasswordsButton` |
| live-app-sheet-window | entry | Queries auf `reisen.sync.remember-login.sheet` + descendants — nicht Main-Window für den fehlenden Button | `MacUI.openRememberLoginSheet` |
| live-app-ui-compile | contract | XCUI-Dateien: XCTest + `UITestingIdentifiers` (Foundation). Kein neues SwiftUI-Produkt im Runner. | Compile der MacUI-Targets |
| live-app-process-hooks | capability | Kein neuer `use(suite)` / globaler Suite-Hook | Diff-Grep |
| live-app-disclosure-seed | capability | Populated-XCUI setzt `ProviderLoginDisclosureKeys.accepted` in **isolatedDefaults** (nicht `.standard`). Alert erscheint nicht; Smoke tippt **Verstanden** nicht (`accept()` würde `.standard` schreiben). | `UITestingLaunchTests` + AppBootstrap-Call |

## Isolation-Grep (Ist-Code, vollständig)

Treffer in Sync-/Sheet-Nachbarschaft. Kein repräsentatives Listing.

| Datei:Zeile | Treffer | Journey-Wirkung (Sheet auf, kein Speichern) |
| --- | --- | --- |
| `SyncView.swift:20–33` | `@AppStorage` Notifications, Kalender, `rememberLoginAutomatically`, `isProviderEnabled`, `preferredKeychainAccountID` (ohne `store:`) | Read beim Launch. Journey schreibt sie nicht. `preferredKeychainAccountID` nur in `onSaved`. |
| `SyncView.swift:55` | `AppStorage(providerEnabledKey)` | Launch/Enable; Smoke tippt Enable nicht. |
| `SyncView.swift:59` | `AppStorage(preferredKeychainAccountKey)` | Write nur `onSaved`. |
| `SyncTab.swift:50` | `@AppStorage(rememberLoginAutomatically)` | Read. Auto-Save nicht durch Sheet-Öffnen. |
| `SyncTab.swift:310` | `UserDefaults.standard.string` preferred account | Read. |
| `SyncTab.swift:316` | `UserDefaults.standard.set` | Nur `setPreferredKeychainAccountID` nach Speichern. XCUI ist macOS. |
| `SyncTab.swift:535` | `settings: .fromUserDefaults()` | Sync-Button, nicht diese Journey. |
| `GlobalChrome.swift:50` | `settings: .fromUserDefaults()` | Sync-all, nicht diese Journey. |
| `ProviderLoginDisclosureModifier.swift:6` | `@AppStorage(ProviderLoginDisclosureKeys.accepted)` ohne `store:` | In XCUI via `defaultAppStorage(isolatedDefaults)`. Unseeded → Alert. |
| `ProviderLoginDisclosure.swift:43–48` | `isAccepted` / `accept(defaults: .standard)` | `accept()` schreibt `.standard`. Journey darf **Verstanden** nicht tippen. |
| `SyncView.swift:331` | `.providerLoginDisclosure(isActive:)` | `presentIfNeeded()` beim Sync-Öffnen wenn nicht akzeptiert. |
| `SaveProviderCredentialSheet.swift` | keine | — |
| `UITestingIdentifiers.swift` / `MacUI.swift` / `MacUISmokeTests.swift` | keine | — |
| `supportDirectoryURL` in diesen Dateien | keine | — |

`SyncView.onAppear`: bei `UITestingLaunch.isActive` sofort `return` — kein Keychain-Reload im XCUI-Launch.

Identifier-Eindeutigkeit: `syncRememberLogin` hängt an Login-Chrome (Z. 513) **und** Bottom-Bar (Z. 622). Bottom-Bar nur bei `sessionReady`. XCUI-Journey ist `needsLogin` (wie `testProviderSyncChromeIsReachable`) → **ein** Element. Neue IDs `….sheet` / `….username` / `….password` sind neu und eindeutig. `syncOpenPasswords` bleibt nur Chrome.

## Akzeptanz

1. Dialog **Anmeldung merken** (`passwordManual`) hat **keinen** Button **Passwörter öffnen**.
2. Username-Feld ist `.username`, nicht `.emailAddress`.
3. Passwort-Feld ist `.password`, nicht `.newPassword`.
4. Beide Felder bleiben in derselben Section/View.
5. iOS-Username: E-Mail-Keyboard + keine Autokorrektur/Autocap.
6. Chrome-Button **Passwörter öffnen** existiert weiter, wenn die Chrome ihn heute zeigt.
7. XCUI: Sheet erreichen, Felder per Identifier, kein Sheet-Button **Passwörter öffnen**; kein Speichern.

## Tests

| Ebene | Was |
| --- | --- |
| Unit (`ReisenProviderSyncTests`) | `ProviderRememberLoginAutoFill`: username == `.username` ≠ `.emailAddress`; password == `.password` ≠ `.newPassword` |
| Identifier (`ReisenSharedUITests`) | neue IDs stabil |
| XCUI (`MacUISmokeTests`) | nach `syncRememberLogin`: Sheet + Username/Passwort existieren; in **Sheet-Scope** kein Button mit Titel „Passwörter öffnen“ / „Open Passwords“; Cancel oder Dismiss ohne Save |

OS-Popover selbst: `open_gaps` (nicht assertbar).

## Isolation (live_app)

Launch: `MacUI.launchPopulated`, CloudKit aus. Populated-Seed setzt Disclosure-Accepted in **isolatedDefaults** (wie Setup-Hide), damit der First-Sync-Alert die Journey nicht blockiert und `UserDefaults.standard` unberührt bleibt. Smoke tippt weder **Verstanden** noch **Speichern**. Inner-Grep (Plan Task 5) ist nur Diff-Regression zusätzlich zur Tabelle.

## open_gaps

- Associated Domains / Ansatz 1
- XCUI auf das System-Passwörter-Popover
- iOS-XCUI
