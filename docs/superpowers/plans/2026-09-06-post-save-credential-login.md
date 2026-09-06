# Post-Save Credential Login Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Nach Speichern eines Portal-Passwort-Kontos bei `needsLogin` automatisch denselben Fill+Submit-Pfad wie „Zugangsdaten ausfüllen“ ausführen — macOS und iOS über eine SSOT-Entscheidung.

**Architecture:** Promote der Parent-Spec (Keychain + `KeychainAutoFill.applyAccount`). Neue reine Entscheidung `ProviderRememberLogin.loginContinueAfterSave`. Hosts `SyncView`/`SyncTab` rufen nach `onSaved` `reloadKeychainAccounts(selecting:autoFill:)` mit `decision.shouldAutoFill`. Kein zweiter Fill-Pfad.

**Tech Stack:** Swift, Swift Testing, `DiagnosticLogger`/`DiagnosticEvent`, bestehende WebKit-Fill-Pipeline, `Scripts/ci-test.sh`

## Global Constraints

- Spec `docs/superpowers/specs/2026-09-06-post-save-credential-login-design.md` ist Verhaltens-SSOT.
- Parent-Architektur `docs/superpowers/specs/2026-07-17-provider-credential-autofill-design.md` nicht neu erfinden.
- Keine Secrets/Usernames/Account-IDs in Logs; `reason` nur `needs_login` / `session_ready` / `session_only`.
- XCUI-Smoke bleibt Reach-only: kein Tap auf Speichern oder Ausfüllen.
- Kein neues `@AppStorage` / `UserDefaults.standard`.
- Write-time Refactor-Bar; bestehende Asserts nicht schwächen.
- Tests: `bash ./Scripts/ci-test.sh` (Orchestrator misst). Gezielt: `--filter ProviderRememberLoginTests` bzw. ReisenProvidersTests.

---

### Task 1: LoginContinueAfterSave-Vertrag

**Files:**
- Modify: `Sources/ReisenProviders/ProviderRememberLogin.swift`
- Modify: `Tests/ReisenProvidersTests/ProviderRememberLoginTests.swift`

**Interfaces:**
- Consumes: `KeychainCredentialAccount`, `ProviderRememberLoginMode` (`.passwordManual`, `.passwordPrefill`, `.sessionOnly`)
- Produces: `ProviderRememberLogin.LoginContinueAfterSave` mit `preferredAccountID: String`, `shouldAutoFill: Bool`, `reason: String`; `ProviderRememberLogin.loginContinueAfterSave(account:sessionNeedsLogin:mode:) -> LoginContinueAfterSave`

- [ ] **Step 1: Write the failing tests**

Append to `Tests/ReisenProvidersTests/ProviderRememberLoginTests.swift`:

```swift
@Test
func loginContinueAfterSave_fillsWhenNeedsLoginAndPasswordMode() {
    let account = KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de")

    let manual = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: true,
        mode: .passwordManual
    )
    #expect(manual.preferredAccountID == account.id)
    #expect(manual.shouldAutoFill)
    #expect(manual.reason == "needs_login")

    let prefill = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: true,
        mode: .passwordPrefill(username: "u@x.de", password: "pw")
    )
    #expect(prefill.preferredAccountID == account.id)
    #expect(prefill.shouldAutoFill)
    #expect(prefill.reason == "needs_login")
}

@Test
func loginContinueAfterSave_skipsSessionOnlyEvenWhenNeedsLogin() {
    let account = KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de")
    let decision = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: true,
        mode: .sessionOnly
    )
    #expect(decision.preferredAccountID == account.id)
    #expect(!decision.shouldAutoFill)
    #expect(decision.reason == "session_only")
}

@Test
func loginContinueAfterSave_skipsWhenSessionReady() {
    let account = KeychainCredentialAccount(serverHost: "opodo.de", username: "a@x.de")

    let readyManual = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: false,
        mode: .passwordManual
    )
    #expect(readyManual.preferredAccountID == account.id)
    #expect(!readyManual.shouldAutoFill)
    #expect(readyManual.reason == "session_ready")

    let readySession = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: false,
        mode: .sessionOnly
    )
    #expect(readySession.preferredAccountID == account.id)
    #expect(!readySession.shouldAutoFill)
    #expect(readySession.reason == "session_ready")
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run from the worktree:

```bash
swift test --filter loginContinueAfterSave
```

Expected: FAIL — `loginContinueAfterSave` is not a member of `ProviderRememberLogin`.

- [ ] **Step 3: Write minimal implementation**

In `Sources/ReisenProviders/ProviderRememberLogin.swift`, inside `enum ProviderRememberLogin`, add:

```swift
public struct LoginContinueAfterSave: Equatable, Sendable {
    public let preferredAccountID: String
    public let shouldAutoFill: Bool
    public let reason: String

    public init(preferredAccountID: String, shouldAutoFill: Bool, reason: String) {
        self.preferredAccountID = preferredAccountID
        self.shouldAutoFill = shouldAutoFill
        self.reason = reason
    }
}

public static func loginContinueAfterSave(
    account: KeychainCredentialAccount,
    sessionNeedsLogin: Bool,
    mode: ProviderRememberLoginMode
) -> LoginContinueAfterSave {
    guard sessionNeedsLogin else {
        return LoginContinueAfterSave(
            preferredAccountID: account.id,
            shouldAutoFill: false,
            reason: "session_ready"
        )
    }
    switch mode {
    case .passwordManual, .passwordPrefill:
        return LoginContinueAfterSave(
            preferredAccountID: account.id,
            shouldAutoFill: true,
            reason: "needs_login"
        )
    case .sessionOnly:
        return LoginContinueAfterSave(
            preferredAccountID: account.id,
            shouldAutoFill: false,
            reason: "session_only"
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

```bash
swift test --filter loginContinueAfterSave
```

Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

Only if the user asked to commit in this session; otherwise leave uncommitted. If committing:

```bash
git add Sources/ReisenProviders/ProviderRememberLogin.swift Tests/ReisenProvidersTests/ProviderRememberLoginTests.swift
git commit -m "$(cat <<'EOF'
feat: decide post-save credential fill from session and mode

EOF
)"
```

---

### Task 2: Hosts — Post-Save-Continue + Logging

**Files:**
- Modify: `Sources/Reisen/App/SyncView.swift` (Save-Sheet `onSaved`, ca. Zeilen 244–255)
- Modify: `Apps/ReiseniOS/ProviderSync/SyncTab.swift` (Save-Sheet `onSaved`, ca. Zeilen 89–101)
- Test: `Tests/ReisenProvidersTests/ProviderRememberLoginTests.swift` (Task 1 bleibt der Vertrags-Test; Hosts verdrahten nur die SSOT)

**Interfaces:**
- Consumes: `ProviderRememberLogin.loginContinueAfterSave(account:sessionNeedsLogin:mode:)`
- Produces: Hosts setzen `decision.preferredAccountID`, laden Konten mit `autoFill: decision.shouldAutoFill`, loggen `credential_save_continue`

- [ ] **Step 1: Confirm the macOS Spec-gap and iOS split path**

Ist-Code `SyncView` `onSaved` ruft `reloadKeychainAccounts(selecting: account)` ohne `autoFill: true`. Ist-Code `SyncTab` `onSaved` setzt das Konto und ruft `scheduleAutoFillFromKeychain()` ohne Konten-Reload. Beide weichen von der Spec ab.

Es gibt keinen isolierten Host-Unit-Test für `onSaved`. Der fachliche Assert bleibt Task 1. Nach dem Edit muss ein Grep gelten:

- `SyncView` Sheet-`onSaved` enthält `applyAfterSavedAccount` und `reloadKeychainAccounts(selecting: account, autoFill:`
- `SyncTab` Sheet-`onSaved` enthält `applyAfterSavedAccount` und `reloadKeychainAccounts(autoFill:` und **keinen** direkten `scheduleAutoFillFromKeychain()` in diesem Closure

- [ ] **Step 2: Wire macOS**

Replace the `SaveProviderCredentialSheet` trailing closure in `Sources/Reisen/App/SyncView.swift` with:

```swift
) { account in
    let decision = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: sessionStatus == .needsLogin,
        mode: rememberLoginMode
    )
    preferredKeychainAccountID = decision.preferredAccountID
    reloadKeychainAccounts(selecting: account, autoFill: decision.shouldAutoFill)
    rememberLoginMessage = L10n.format(.credentialSavedForHost, keychainServerHost)
    let context = DiagnosticContext(
        runID: diagnosticRunID,
        providerID: providerID,
        operation: "auto_login"
    )
    Task {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "SyncView",
                phase: "keychain",
                event: "credential_save_continue",
                result: decision.shouldAutoFill ? .started : .skipped,
                reason: decision.reason
            )
        )
    }
}
```

`DiagnosticLogger` kommt in `SyncView`/`SyncTab` über `ReisenAppCore` (`@_exported import ReisenDiagnostics`). Keinen Inline-Import.

- [ ] **Step 3: Wire iOS**

iOS-`reloadKeychainAccounts` hat nur `autoFill:` (kein `selecting:`). Preferred-ID zuerst setzen, dann Reload. Replace the `SaveProviderCredentialSheet` trailing closure in `Apps/ReiseniOS/ProviderSync/SyncTab.swift` with:

```swift
) { account in
    showCredentialSheet = false
    let decision = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: sessionStatus == .needsLogin,
        mode: rememberLoginMode
    )
    setPreferredKeychainAccountID(decision.preferredAccountID)
    reloadKeychainAccounts(autoFill: decision.shouldAutoFill)
    rememberLoginMessage = L10n.format(.credentialSavedForHost, host)
    let context = DiagnosticContext(
        runID: diagnosticRunID,
        providerID: selectedProviderID,
        operation: "ios_auto_login"
    )
    Task {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "SyncTab",
                phase: "keychain",
                event: "credential_save_continue",
                result: decision.shouldAutoFill ? .started : .skipped,
                reason: decision.reason
            )
        )
    }
}
```

Nicht `selectedKeychainAccount = account` plus separatem `scheduleAutoFillFromKeychain()` im Closure.

- [ ] **Step 4: Run targeted tests + compile**

```bash
swift test --filter ProviderRememberLoginTests
```

Expected: PASS.

Dann Compiler:

```bash
bash ./Scripts/ci-build.sh --arch arm64
```

Expected: Exit 0. Wenn iOS-Target nicht in diesem Script liegt, zusätzlich nach Repo-Konvention `bash ./Scripts/generate-ios-project.sh` nicht anstoßen außer der iOS-Edit bricht den macOS-Build; iOS-Syntax prüft der Orchestrator mit `bash ./Scripts/ios-test.sh` nur wenn das Script im Worktree lauffähig ist.

- [ ] **Step 5: Isolation-Grep (live_app)**

```bash
rg -n "AppStorage\\(|@AppStorage|UserDefaults.standard|fromUserDefaults|supportDirectoryURL" \
  Sources/Reisen/App/SyncView.swift \
  Apps/ReiseniOS/ProviderSync/SyncTab.swift \
  Sources/ReisenProviders/ProviderRememberLogin.swift \
  Sources/ReisenProviderSync/SaveProviderCredentialSheet.swift \
  Sources/ReisenProviders/KeychainAutoFill.swift
```

Expected: nur die in der Spec-Isolationstabelle gelisteten Treffer. Kein neuer Persistenz-Site im Diff. `supportDirectoryURL` bleibt ohne Treffer.

- [ ] **Step 6: Commit**

Nur auf User-Wunsch. Sonst uncommitted lassen.

---

### Task 3: Verify + Smoke-Vertrag

**Files:**
- Verify only: `Tests/ReisenMacUITests/MacUISmokeTests.swift` (`testProviderSyncChromeIsReachable`)
- Verify only: `Tests/ReisenSharedUITests/UITestingIdentifiersTests.swift`

**Interfaces:**
- Consumes: bestehende Identifier `reisen.sync.remember-login`, `reisen.sync.fill-credentials`
- Produces: unveränderte Reach-only-Evidence

- [ ] **Step 1: Confirm smoke remains reach-only**

`testProviderSyncChromeIsReachable` muss weiterhin:

- `waitFor(UITestingIdentifiers.syncRememberLogin)`
- `XCTAssertFalse` auf `syncFillCredentials` ohne Konto
- **kein** `tap` auf Remember-Login / Speichern / Fill

Keine Code-Änderung an den Smokes, außer ein Identifier-Test bricht (dann Fix, nicht Skip).

- [ ] **Step 2: Full test command**

```bash
bash ./Scripts/ci-test.sh
```

Expected: Exit 0.

- [ ] **Step 3: UI-Diff (Agent-Pflicht bei UI-Host-Änderung)**

```bash
bash ./Scripts/macos-ui-test-remote.sh
```

Expected: Exit 0 (Diff-Default). Lokal `macos-ui-test.sh` nur nach nachgewiesenem Remote-Connect-Fehler.

- [ ] **Step 4: Commit**

Nur auf User-Wunsch.
