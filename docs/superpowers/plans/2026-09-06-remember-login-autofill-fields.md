# Remember-Login AutoFill Fields Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Button „Passwörter öffnen“ aus dem Dialog „Anmeldung merken“ entfernen und Username- plus Passwort-Feld nach Apple Password AutoFill markieren.

**Architecture:** Promote der Sheet-Architektur (Ansatz 3). SSOT `ProviderRememberLoginAutoFill` in `ReisenProviderSync`; Sheet wendet Types an und verliert `onOpenPasswordManager`. Sync-Chrome-Button bleibt.

**Tech Stack:** SwiftUI, `NSTextContentType`, Swift Testing, macOS XCUI (`MacUISmokeTests`), `Scripts/ci-test.sh`, `Scripts/macos-ui-test-remote.sh`

## Global Constraints

- Content-Types exakt: Username `.username` (nicht `.emailAddress`); Passwort `.password` (nicht `.newPassword`).
- SSOT plattformgetrennt: iOS `UITextContentType`, macOS `NSTextContentType` — kein AppKit-only-Typ in `ReisenProviderSync`.
- Keine Associated Domains / keine neuen Entitlements.
- Chrome `reisen.sync.open-passwords` nicht entfernen.
- XCUI reach-only: Sheet öffnen, nicht Speichern.
- Logging entbehrlich (kein neuer I/O-Pfad).
- Identifier nur über `UITestingIdentifiers`.
- `git diff --check` sauber.

---

### Task 1: AutoFill-SSOT + Sheet ohne Open-Passwords-Button

**Files:**
- Create: `Sources/ReisenProviderSync/ProviderRememberLoginAutoFill.swift`
- Create: `Tests/ReisenProviderSyncTests/ProviderRememberLoginAutoFillTests.swift`
- Modify: `Package.swift` (`ReisenProviderSync` += `ReisenSharedUI`)
- Modify: `Sources/ReisenProviderSync/SaveProviderCredentialSheet.swift`
- Modify: `Sources/Reisen/App/SyncView.swift` (Sheet-Call ohne Callback)
- Modify: `Sources/ReisenSharedUI/UITestingIdentifiers.swift`
- Modify: `Tests/ReisenSharedUITests/UITestingIdentifiersTests.swift`
- Modify: `Tests/ReisenMacUITests/MacUI.swift`
- Modify: `Sources/ReisenAppCore/UITestingLaunch.swift`
- Modify: `Sources/ReisenAppCore/AppBootstrap.swift` (Seed-Call neben Setup)
- Modify: `Tests/ReisenAppCoreTests/UITestingLaunchTests.swift`
- Modify: `Tests/ReisenMacUITests/MacUISmokeTests.swift`

**Interfaces:**
- Consumes: Apple-Vertrag aus der Spec; bestehendes Sheet-API
- Produces: `ProviderRememberLoginAutoFill.usernameContentType` / `passwordContentType`; Sheet-Init ohne `onOpenPasswordManager`; Identifier `syncRememberLoginSheet`, `syncRememberLoginUsername`, `syncRememberLoginPassword`

- [ ] **Step 1: Write the failing tests**

`Tests/ReisenProviderSyncTests/ProviderRememberLoginAutoFillTests.swift`:

```swift
import Testing
@testable import ReisenProviderSync

@Test func rememberLoginAutoFill_usesUsernameNotEmailAddress() {
    #expect(ProviderRememberLoginAutoFill.usernameContentType == .username)
    #expect(ProviderRememberLoginAutoFill.usernameContentType != .emailAddress)
}

@Test func rememberLoginAutoFill_usesPasswordNotNewPassword() {
    #expect(ProviderRememberLoginAutoFill.passwordContentType == .password)
    #expect(ProviderRememberLoginAutoFill.passwordContentType != .newPassword)
}
```

In `UITestingIdentifiersTests` ergänzen:

```swift
#expect(UITestingIdentifiers.syncRememberLoginSheet == "reisen.sync.remember-login.sheet")
#expect(UITestingIdentifiers.syncRememberLoginUsername == "reisen.sync.remember-login.username")
#expect(UITestingIdentifiers.syncRememberLoginPassword == "reisen.sync.remember-login.password")
#expect(UITestingIdentifiers.syncOpenPasswords == "reisen.sync.open-passwords")
```

In `UITestingIdentifiers.swift` die drei neuen `static let` direkt unter `syncRememberLogin` anlegen.

In `MacUI.swift` Page-Object (Sheet-Fenster, nicht Main-Window):

```swift
@discardableResult
func openRememberLoginSheet() -> XCUIElement {
    waitFor(UITestingIdentifiers.syncRememberLogin).click()
    return waitFor(UITestingIdentifiers.syncRememberLoginSheet)
}

func rememberLoginSheet() -> XCUIElement {
    element(UITestingIdentifiers.syncRememberLoginSheet)
}
```

In `UITestingLaunchTests.swift` (RED zuerst):

```swift
@Test func uiTestingLaunch_seedLoginDisclosureOnlyForPopulated() {
    let suite = "ReisenTests.uiTesting.disclosure.\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suite) else {
        Issue.record("UserDefaults suite konnte nicht erzeugt werden")
        return
    }
    defer { defaults.removePersistentDomain(forName: suite) }

    UITestingLaunch.seedProviderLoginDisclosureIfNeeded(mode: .empty, defaults: defaults)
    #expect(!ProviderLoginDisclosure.isAccepted(defaults: defaults))

    UITestingLaunch.seedProviderLoginDisclosureIfNeeded(mode: .populated, defaults: defaults)
    #expect(ProviderLoginDisclosure.isAccepted(defaults: defaults))
}
```

In `MacUISmokeTests.swift` neuer Smoke — **kein** Save-Tap, **kein** Tap auf „Verstanden“:

```swift
func testRememberLoginSheetHasAutofillFieldsWithoutOpenPasswordsButton() {
    let ui = MacUI.launchPopulated()
    ui.waitForWindow()
    ui.openProviderSyncCheck24()
    _ = ui.waitForSyncLoginChrome()
    let sheet = ui.openRememberLoginSheet()
    XCTAssertTrue(
        sheet.descendants(matching: .any)[UITestingIdentifiers.syncRememberLoginUsername]
            .firstMatch.waitForExistence(timeout: 5)
    )
    XCTAssertTrue(
        sheet.descendants(matching: .any)[UITestingIdentifiers.syncRememberLoginPassword]
            .firstMatch.exists
    )
    XCTAssertFalse(
        sheet.buttons["Passwörter öffnen"].exists,
        "Sheet darf keinen Passwörter-öffnen-Button haben"
    )
    XCTAssertFalse(
        sheet.buttons["Open Passwords"].exists,
        "Sheet must not show Open Passwords"
    )
}
```

- [ ] **Step 2: Run tests to verify they fail**

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-remember-login-autofill-fields
swift test --filter rememberLoginAutoFill_usesUsernameNotEmailAddress
```

Expected: FAIL (Typ `ProviderRememberLoginAutoFill` fehlt). Identifier-Asserts FAIL bis die `static let` existieren. XCUI FAIL bis Sheet-ID und Button weg sind.

- [ ] **Step 3: Write minimal implementation**

`Sources/ReisenProviderSync/ProviderRememberLoginAutoFill.swift`:

```swift
#if os(iOS)
import UIKit
#else
import AppKit
#endif

/// Apple Password AutoFill für native Felder im Dialog „Anmeldung merken“.
/// SSOT: Enabling Password AutoFill on a text input view — username + password.
public enum ProviderRememberLoginAutoFill {
    #if os(iOS)
    public static let usernameContentType = UITextContentType.username
    public static let passwordContentType = UITextContentType.password
    #else
    public static let usernameContentType = NSTextContentType.username
    public static let passwordContentType = NSTextContentType.password
    #endif
}
```

SwiftUI-Felder nutzen `.textContentType(ProviderRememberLoginAutoFill.usernameContentType)` bzw. `.passwordContentType` — der Modifier akzeptiert den plattformrichtigen Typ.

`Package.swift`: in `ReisenProviderSync.dependencies` `"ReisenSharedUI"` ergänzen.

`SaveProviderCredentialSheet`: Import `ReisenSharedUI`. Parameter `onOpenPasswordManager` und den Button-Block entfernen. Felder:

```swift
TextField(L10n.string(.credentialEmailUsername), text: $username)
    .textContentType(ProviderRememberLoginAutoFill.usernameContentType)
    .accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginUsername)
#if os(iOS)
    .textInputAutocapitalization(.never)
    .autocorrectionDisabled()
    .keyboardType(.emailAddress)
#endif
SecureField(L10n.string(.credentialPassword), text: $password)
    .textContentType(ProviderRememberLoginAutoFill.passwordContentType)
    .accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginPassword)
```

Am `NavigationStack` oder äußeren Container:

```swift
.accessibilityIdentifier(UITestingIdentifiers.syncRememberLoginSheet)
```

`UITestingLaunch.seedProviderLoginDisclosureIfNeeded(mode:defaults:)`:

```swift
public static func seedProviderLoginDisclosureIfNeeded(
    mode: UITestingMode,
    defaults: UserDefaults
) {
    guard mode == .populated else { return }
    ProviderLoginDisclosure.accept(defaults: defaults)
}
```

In `AppBootstrap.applyProviderEnabledDefaultsMigration` direkt nach `seedProviderSetupIfNeeded`:

```swift
UITestingLaunch.seedProviderLoginDisclosureIfNeeded(mode: uiTesting, defaults: defaults)
```

`SyncView` Sheet-Call: `onOpenPasswordManager:`-Argument entfernen. `keychainAssistanceActionButtons` nicht anfassen. Smoke tippt **Verstanden** nicht.

- [ ] **Step 4: Run the tests and make sure they pass**

```bash
cd /Users/roschmac/Entwicklung/Reisen/.worktrees/feat-remember-login-autofill-fields
bash ./Scripts/ci-test.sh
bash ./Scripts/macos-ui-test-remote.sh
```

Expected: Unit/Identifier grün; Diff-XCUI führt `testRememberLoginSheetHasAutofillFieldsWithoutOpenPasswordsButton` aus und ist grün.

- [ ] **Step 5: Isolation-Grep (Diff-Regression)**

P1-Vertrag (Ist-Hits) steht in der Spec-Tabelle. Dieser Schritt prüft nur, dass der **Diff** keine neuen `@AppStorage` / `AppStorage(` / `UserDefaults.standard` / `fromUserDefaults` / `supportDirectoryURL` einführt. Evidence ins Ledger.

- [ ] **Step 6: Commit**

Nur auf explizite User-Anweisung. Kein Cursor-Co-Author.
