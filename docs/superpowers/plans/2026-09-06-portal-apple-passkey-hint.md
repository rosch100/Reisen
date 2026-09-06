# Portal Apple-Passkey-Hinweis Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Wenn ein Portal „Anmelden mit Apple“ öffnet (auch im Auth-Popup), zeigt der Sync-Chrome, dass Passkey in der App nicht geht und der Apple-Benutzername eingegeben werden muss.

**Architecture:** Vertrag bleibt `AuthIdentityProviderHost.showsApplePasskeyHint` in ReisenProviders; sichtbare URL = Parent **oder** Auth-Popup. Composition reicht die Popup-URL per Binding/Callback durch, ohne `hub.updateWebView` auf das Kind. SharedUI rendert Copy + Identifier.

**Tech Stack:** Swift, SwiftUI, WKWebView, Swift Testing, macOS XCUI (`UITestingIdentifiers`), `DiagnosticLogger`.

## Global Constraints

- Copy-SSOT DE: „Die Passkey-Anmeldung funktioniert in der App nicht. Gib den Apple-Benutzernamen ein.“
- Copy-SSOT EN: „Passkey sign-in does not work in the app. Enter your Apple username.“
- L10n-Key bleibt `sync.apple_passkey_hint` / `L10nKey.syncApplePasskeyHint`
- Nutzer-Copy sagt **Portal**, nicht Provider; **Passwort** nicht „Kennwort“
- Auth-Popup darf nicht `ProviderSessionNavigation.handleDidFinish` / `hub.updateWebView` auf dem Kind auslösen
- Kein neues `@AppStorage` / `UserDefaults.standard` / `supportDirectoryURL`
- Identifier `reisen.sync.apple-passkey-hint` höchstens ein Element
- XCUI: Existence-only; kein Tap auf den Hinweis; kein Apple-IdP-Seed
- Logging nur `DiagnosticLogger` / `DiagnosticEvent`; URL-Redaction der Diagnostics-SSOT
- Tests: `bash ./Scripts/ci-test.sh`; UI-Diff: `bash ./Scripts/macos-ui-test-remote.sh`
- Write-time Refactor-Bar; TDD: RED fachlich vor Implementation

---

### Task 1: Hinweis-Vertrag + Copy

**Files:**
- Modify: `Sources/ReisenProviders/AuthIdentityProviderHost.swift`
- Modify: `Tests/ReisenProvidersTests/AuthPageURLHeuristicTests.swift`
- Modify: `Sources/ReisenDomain/Resources/Localizable.xcstrings` (`sync.apple_passkey_hint`)
- Modify: `Tests/ReisenDomainTests/L10nTests.swift`
- Test: dieselben Testdateien

**Interfaces:**
- Consumes: bestehendes `showsApplePasskeyHint(needsLogin:urlAbsoluteString:)`
- Produces: `showsApplePasskeyHint(needsLogin:urlAbsoluteString:authPopupURLAbsoluteString:)` — Default `authPopupURLAbsoluteString: String? = nil`; `true` bei `needsLogin` und Apple-Host in Parent **oder** Popup

- [ ] **Step 1: Write the failing tests**

In `Tests/ReisenProvidersTests/AuthPageURLHeuristicTests.swift` den bestehenden Test `appleIdAuthIsLoginButNoPasswordAutofill` um Popup-Fälle erweitern bzw. neuen Test ergänzen:

```swift
@Test func applePasskeyHintUsesAuthPopupURLWhileParentStaysOnPortal() {
    let portal = "https://www.traveloka.com/en-en/user/signin"
    let apple = "https://appleid.apple.com/auth/authorize?client_id=x"
    let google = "https://accounts.google.com/signin"
    #expect(
        AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: true,
            urlAbsoluteString: portal,
            authPopupURLAbsoluteString: apple
        )
    )
    #expect(
        !AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: true,
            urlAbsoluteString: portal,
            authPopupURLAbsoluteString: nil
        )
    )
    #expect(
        !AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: true,
            urlAbsoluteString: portal,
            authPopupURLAbsoluteString: google
        )
    )
    #expect(
        !AuthIdentityProviderHost.showsApplePasskeyHint(
            needsLogin: false,
            urlAbsoluteString: portal,
            authPopupURLAbsoluteString: apple
        )
    )
}
```

In `Tests/ReisenDomainTests/L10nTests.swift` in `l10n_deCopyClarity_terminologySSOT` bzw. eigenem Test:

```swift
@Test func l10n_syncApplePasskeyHint_namesPasskeyAndAppleUsername() {
    L10n.withLocale(Locale(identifier: "de")) {
        let de = L10n.string(.syncApplePasskeyHint)
        #expect(de == "Die Passkey-Anmeldung funktioniert in der App nicht. Gib den Apple-Benutzernamen ein.")
    }
    L10n.withLocale(Locale(identifier: "en")) {
        let en = L10n.string(.syncApplePasskeyHint)
        #expect(en == "Passkey sign-in does not work in the app. Enter your Apple username.")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `bash ./Scripts/ci-test.sh` (oder gezielter Swift-Testing-Filter `applePasskeyHint` / `l10n_syncApplePasskeyHint`)

Expected: FAIL — `showsApplePasskeyHint` kennt `authPopupURLAbsoluteString` nicht bzw. ignoriert Popup; L10n-Assert trifft den alten Safari/Passwort-Text.

- [ ] **Step 3: Write minimal implementation**

`AuthIdentityProviderHost.showsApplePasskeyHint`:

```swift
public static func showsApplePasskeyHint(
    needsLogin: Bool,
    urlAbsoluteString: String?,
    authPopupURLAbsoluteString: String? = nil
) -> Bool {
    guard needsLogin else { return false }
    if let authPopupURLAbsoluteString, matchesApple(urlAbsoluteString: authPopupURLAbsoluteString) {
        return true
    }
    guard let urlAbsoluteString else { return false }
    return matchesApple(urlAbsoluteString: urlAbsoluteString)
}
```

`Localizable.xcstrings` Key `sync.apple_passkey_hint`: DE/EN auf die Spec-Sätze setzen (beide `state: translated`).

- [ ] **Step 4: Run tests to verify they pass**

Run: dieselben Filter / `ci-test.sh` für Domain+Providers

Expected: PASS

- [ ] **Step 5: Commit** (nur wenn der Orchestrator P4/User-Commit anstößt — Inner committet nicht selbst)

---

### Task 2: Popup-URL in den Sync-Chrome + Log + Identifier

**Files:**
- Modify: `Sources/Reisen/Platform/ProviderSessionView.swift` (`ProviderSessionView`, `ProviderWebView`, `Coordinator`)
- Modify: `Sources/Reisen/App/SyncView.swift`
- Modify: `Apps/ReiseniOS/ProviderSync/WebViewHost.swift`
- Modify: `Apps/ReiseniOS/ProviderSync/SyncTab.swift`
- Modify: `Sources/ReisenSharedUI/SyncApplePasskeyHintLabel.swift`
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift`
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift` (`testProviderSyncChromeIsReachable`)

**Interfaces:**
- Consumes: `showsApplePasskeyHint(needsLogin:urlAbsoluteString:authPopupURLAbsoluteString:)` aus Task 1
- Produces: Binding/Callback `authPopupURLAbsoluteString: String?`; Identifier `UITestingIdentifiers.syncApplePasskeyHint`; Diagnostic `SyncApplePasskeyHint` / `login` / `apple_passkey_hint`

- [ ] **Step 1: Write the failing XCUI assert (Negativ)**

In `UITestingIdentifiers.swift`:

```swift
public static let syncApplePasskeyHint = "reisen.sync.apple-passkey-hint"
```

In `testProviderSyncChromeIsReachable` nach `waitForSyncLoginChrome()`:

```swift
XCTAssertEqual(
    ui.app.descendants(matching: .any)
        .matching(identifier: UITestingIdentifiers.syncApplePasskeyHint)
        .count,
    0,
    "Passkey-Hinweis nur bei Apple-IdP, nicht auf Check24-Login"
)
```

Identifier am Label fehlt → Count bleibt 0 (dieser Assert ist GRÜN ohne Label). Der **fachliche** RED dieses Tasks ist der Unit-Vertrag aus Task 1 plus ein Compile-Fail, wenn SyncView die neue Signatur noch ohne Popup-URL aufruft. Zusätzlich Identifier am Label verdrahten, damit der Count später 1 werden *kann*.

Kein neuer Test, der den Hinweis erzwingt.

- [ ] **Step 2: Isolation-Grep (vollständig, Output vs. Spec-Tabelle)**

Dieselben Pfade wie Spec-Abschnitt „Isolation-Grep“ inkl. Disclosure/Launch-Hooks. Expected: **identisches** Treffer-Set wie in der Spec-Tabelle (2026-09-06). Jede neue Zeile = Blocking. Smoke bleibt Reach-only: kein Tap auf Disclosure-Accept (`UserDefaults.standard`) und keinen Sync-Button (`fromUserDefaults`).

- [ ] **Step 3: Implement popup URL plumbing (kein handleDidFinish auf dem Kind)**

macOS: `ProviderSessionView` / `ProviderWebView` / `Coordinator` um `@Binding var authPopupURLAbsoluteString: String?` erweitern (Default-Init für Previews: `.constant(nil)` vermeiden — SyncView reicht echtes `@State`).

In `handleAuthPopupNavigation` nach dem URL-Read:

```swift
authPopupURLAbsoluteString.wrappedValue = url.absoluteString
```

In `dismissAuthPopup`:

```swift
authPopupURLAbsoluteString.wrappedValue = nil
```

`didFinish`/`didCommit` für `webView === authPopupWebView` bleiben beim Early-Return **ohne** `updateSession` (Parent-Session/Hub-WebView unverändert).

iOS: `WebViewHost` / `ProviderSessionWebView` / `Coordinator` analog `onAuthPopupURLChange: ((String?) -> Void)?`. In `handleAuthPopupNavigation`: `onAuthPopupURLChange?(url.absoluteString)`. In `dismissAuthPopup`: `onAuthPopupURLChange?(nil)`. Weiter **kein** `onDidFinish(popup)`.

`SyncView` / `SyncTab`:

```swift
@State private var authPopupURLAbsoluteString: String?

private var showsApplePasskeyHint: Bool {
    AuthIdentityProviderHost.showsApplePasskeyHint(
        needsLogin: sessionStatus == .needsLogin,
        urlAbsoluteString: lastURLString,
        authPopupURLAbsoluteString: authPopupURLAbsoluteString
    )
}
```

Beim Sichtbar-Wechsel loggen (macOS + iOS), URL roh übergeben:

```swift
.onChange(of: showsApplePasskeyHint) { _, visible in
    guard visible else { return }
    Task {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(
                    runID: /* bestehender Run */,
                    providerID: providerID,
                    operation: "sync_login"
                ),
                component: "SyncApplePasskeyHint",
                phase: "login",
                event: "apple_passkey_hint",
                result: .succeeded,
                url: authPopupURLAbsoluteString ?? lastURLString,
                reason: "apple_idp_visible"
            )
        )
    }
}
```

`SyncApplePasskeyHintLabel`:

```swift
Text(L10n.string(.syncApplePasskeyHint))
    .font(.footnote)
    .foregroundStyle(.secondary)
    .fixedSize(horizontal: false, vertical: true)
    .accessibilityIdentifier(UITestingIdentifiers.syncApplePasskeyHint)
```

- [ ] **Step 4: Run targeted tests**

Run: Providers/Domain-Filter + `bash ./Scripts/ci-test.sh`

Expected: PASS. Compile der macOS- und iOS-Targets über das Script.

- [ ] **Step 5: XCUI Diff-Remote**

Run: `bash ./Scripts/macos-ui-test-remote.sh`

Expected: `testProviderSyncChromeIsReachable` grün; Hint-Count 0 auf Check24.

---

## Self-Review

1. **Spec coverage:** Sichtbarkeit Parent+Popup → Task 1; Copy → Task 1; Popup ohne Hub-Tausch → Task 2; Log → Task 2; Identifier/XCUI-Negativ → Task 2; Isolation-Grep → Task 2.
2. **Placeholders:** keine TBD.
3. **Types:** `authPopupURLAbsoluteString: String?` durchgängig; `showsApplePasskeyHint` dreistellig mit Default `nil`.
