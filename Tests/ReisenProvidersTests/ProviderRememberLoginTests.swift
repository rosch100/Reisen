import Foundation
import Security
import Testing
@testable import ReisenProviders

@Test
func rememberLoginSheetMode_prefillsWhenPendingCredentialsExist() {
    let pending = ProviderCredentials(username: "u@x.de", password: "pw")

    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: false, pending: pending)
            == .passwordPrefill(username: "u@x.de", password: "pw")
    )
    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: true, pending: pending)
            == .passwordPrefill(username: "u@x.de", password: "pw")
    )
}

@Test
func rememberLoginSheetMode_sessionOnlyWhenReadyWithoutPending() {
    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: true, pending: nil) == .sessionOnly
    )
    #expect(
        ProviderRememberLoginMode.forSheet(sessionReady: false, pending: nil) == .passwordManual
    )
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
