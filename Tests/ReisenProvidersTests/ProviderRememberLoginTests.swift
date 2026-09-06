import Foundation
import Security
import Testing
@testable import ReisenProviders

@Test
func rememberLoginSheetMode_prefillsWhenPendingCredentialsExist() {
    let pending = ProviderCredentials(username: "u@x.de", password: "pw")
    let stored = ProviderCredentials(username: "stored@x.de", password: "stored")

    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: false, pending: pending, stored: nil)
            == .passwordPrefill(username: "u@x.de", password: "pw")
    )
    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: true, pending: pending, stored: stored)
            == .passwordPrefill(username: "u@x.de", password: "pw")
    )
}

@Test
func rememberLoginSheetMode_prefersStoredPasswordOverSessionOnly() {
    let stored = ProviderCredentials(username: "stored@x.de", password: "stored-pw")

    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: true, pending: nil, stored: stored)
            == .passwordStored(username: "stored@x.de", password: "stored-pw")
    )
    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: false, pending: nil, stored: stored)
            == .passwordStored(username: "stored@x.de", password: "stored-pw")
    )
}

@Test
func rememberLoginSheetMode_sessionOnlyWhenReadyWithoutPendingOrStored() {
    #expect(
        ProviderRememberLoginMode.forSheet(
            sessionReady: true,
            pending: nil as ProviderCredentials?,
            stored: nil as ProviderCredentials?
        ) == .sessionOnly
    )
    #expect(
        ProviderRememberLoginMode.forSheet(
            sessionReady: false,
            pending: nil as ProviderCredentials?,
            stored: nil as ProviderCredentials?
        ) == .passwordManual
    )
}

@Test
func rememberLoginSheetMode_cancelActionOnlyWhenEditable() {
    #expect(!ProviderRememberLoginMode.sessionOnly.showsCancelAction)
    #expect(ProviderRememberLoginMode.passwordManual.showsCancelAction)
    #expect(
        ProviderRememberLoginMode.passwordPrefill(username: "a", password: "b").showsCancelAction
    )
    #expect(
        ProviderRememberLoginMode.passwordStored(username: "a", password: "b").showsCancelAction
    )
}

@Test
func rememberLoginResolveStoredCredentials_loadsPreferredOrFirst() throws {
    let fake = FakeKeychainInternetPasswordAPI()
    let store = KeychainCredentialStore(keychain: fake)
    let host = "booking.com"
    let preferred = KeychainCredentialAccount(serverHost: host, username: "b@x.de")
    let other = KeychainCredentialAccount(serverHost: host, username: "a@x.de")

    fake.genericAttributeResults = [
        [
            kSecAttrService as CFString: KeychainCredentialQuery.service,
            kSecAttrAccount as CFString: other.id,
        ],
        [
            kSecAttrService as CFString: KeychainCredentialQuery.service,
            kSecAttrAccount as CFString: preferred.id,
        ],
    ]
    fake.genericSecretByAccount = [
        other.id: Data("pw-a".utf8),
        preferred.id: Data("pw-b".utf8),
    ]

    let resolved = try ProviderRememberLogin.resolveStoredCredentials(
        serverHost: host,
        preferredAccountID: preferred.id,
        store: store
    )
    #expect(resolved == ProviderCredentials(username: "b@x.de", password: "pw-b"))
}

@Test
func rememberLoginAutoSave_skipsWhenDisabled() {
    let outcome = ProviderRememberLogin.autoSavePending(
        credentials: ProviderCredentials(username: "u@x.de", password: "pw"),
        serverHost: "booking.com",
        when: false
    )

    #expect(outcome == .skipped)
}

@Test
func rememberLoginAutoSave_savesWhenEnabled() {
    let fake = FakeKeychainInternetPasswordAPI()
    fake.updateStatus = errSecItemNotFound
    let store = KeychainCredentialStore(keychain: fake)

    let outcome = ProviderRememberLogin.autoSavePending(
        credentials: ProviderCredentials(username: "u@x.de", password: "pw"),
        serverHost: "booking.com",
        when: true,
        store: store
    )

    #expect(outcome.account != nil)
    #expect(outcome.message == ProviderRememberLogin.autoSavedMessage(serverHost: "booking.com"))
    #expect(outcome.shouldClearPending)
}

@Test
func keychainAutoFill_pickAccount_prefersExplicitThenStoredThenSingle() {
    let a = KeychainCredentialAccount(serverHost: "booking.com", username: "a@x.de")
    let b = KeychainCredentialAccount(serverHost: "booking.com", username: "b@x.de")

    #expect(KeychainAutoFill.pickAccount(from: [a, b], storedPreferredID: b.id) == b)
    #expect(KeychainAutoFill.pickAccount(from: [a, b], storedPreferredID: "", explicitPreferred: a) == a)
    #expect(KeychainAutoFill.pickAccount(from: [a], storedPreferredID: "") == a)
    #expect(KeychainAutoFill.pickAccount(from: [a, b], storedPreferredID: "") == nil)
}

@Test
func rememberLoginSaveIfNeeded_skipsIdenticalEntry() throws {
    let fake = FakeKeychainInternetPasswordAPI()
    fake.updateStatus = errSecItemNotFound
    let store = KeychainCredentialStore(keychain: fake)
    let credentials = ProviderCredentials(username: "u@x.de", password: "pw")
    let host = "traveloka.com"

    let first = try ProviderRememberLogin.saveIfNeeded(
        credentials: credentials,
        serverHost: host,
        store: store
    )
    #expect(first != nil)

    let second = try ProviderRememberLogin.saveIfNeeded(
        credentials: credentials,
        serverHost: host,
        store: store
    )
    #expect(second == nil)
    #expect(fake.addCalls == 1)
}

@Test
func rememberLoginApplyAutoSaveOutcome_updatesState() {
    var pending: ProviderCredentials? = ProviderCredentials(username: "u@x.de", password: "pw")
    var message: String?
    var savedID: String?

    ProviderRememberLogin.applyAutoSaveOutcome(
        ProviderRememberLogin.AutoSaveOutcome(
            account: KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de"),
            message: "saved",
            shouldClearPending: true
        ),
        pending: &pending,
        message: &message
    ) { account in
        savedID = account.id
    }

    #expect(pending == nil)
    #expect(message == "saved")
    #expect(savedID == "booking.com\u{1f}u@x.de")
}

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

    let stored = ProviderRememberLogin.loginContinueAfterSave(
        account: account,
        sessionNeedsLogin: true,
        mode: .passwordStored(username: "u@x.de", password: "pw")
    )
    #expect(stored.preferredAccountID == account.id)
    #expect(stored.shouldAutoFill)
    #expect(stored.reason == "needs_login")
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

@Test
func applyAfterSavedAccount_setsPreferredIDAndReloadAutoFillWithoutSeparateSchedule() {
    let account = KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de")
    var preferred = ""

    let continueLogin = ProviderRememberLogin.applyAfterSavedAccount(
        account: account,
        sessionNeedsLogin: true,
        mode: .passwordManual,
        setPreferredAccountID: { preferred = $0 }
    )
    #expect(preferred == account.id)
    #expect(continueLogin.preferredAccountID == account.id)
    #expect(continueLogin.shouldAutoFill)
    #expect(continueLogin.reason == "needs_login")

    preferred = "stale"
    let skipReady = ProviderRememberLogin.applyAfterSavedAccount(
        account: account,
        sessionNeedsLogin: false,
        mode: .passwordManual,
        setPreferredAccountID: { preferred = $0 }
    )
    #expect(preferred == account.id)
    #expect(!skipReady.shouldAutoFill)
    #expect(skipReady.reason == "session_ready")
}
