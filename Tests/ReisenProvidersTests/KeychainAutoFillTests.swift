import Foundation
import Security
import Testing
@testable import ReisenProviders

@Test
func keychainAutoFill_appliesStoredCredentials() throws {
    let fake = FakeKeychainInternetPasswordAPI()
    fake.updateStatus = errSecItemNotFound
    let store = KeychainCredentialStore(keychain: fake)
    let account = KeychainCredentialAccount(serverHost: "booking.com", username: "u@x.de")

    try store.save(
        credentials: ProviderCredentials(username: "u@x.de", password: "secret"),
        serverHost: "booking.com"
    )

    let loaded = try store.credentials(for: account)
    #expect(loaded.username == "u@x.de")
    #expect(loaded.password == "secret")
}

@Test
func keychainAutoFillTimingConstants_areStable() {
    #expect(KeychainAutoFill.webViewRetryCount == 10)
    #expect(KeychainAutoFill.webViewRetryDelayNanoseconds == 250_000_000)
    #expect(KeychainAutoFill.loginSettleDelayNanoseconds == 350_000_000)
}

/// macOS/iOS-Parität: bei needsLogin sofort Keychain-Reload+Auto-Fill schedulen (onAppear).
@Test
func keychainAutoFill_schedulesReloadOnAppearOnlyWhenLoginRequired() {
    #expect(KeychainAutoFill.shouldScheduleReloadOnAppear(sessionNeedsLogin: true))
    #expect(!KeychainAutoFill.shouldScheduleReloadOnAppear(sessionNeedsLogin: false))
}

/// Nach erfolgreichem Apply Credentials behalten, solange Login nötig (SPA Re-Apply).
@Test
func keychainAutoFill_retainsCredentialsForReapplyWhileLoginRequired() {
    let credentials = ProviderCredentials(username: "a@b.de", password: "x")
    #expect(
        KeychainAutoFill.retainedCredentialsForReapply(
            sessionNeedsLogin: true,
            applied: credentials
        ) == credentials
    )
    #expect(
        KeychainAutoFill.retainedCredentialsForReapply(
            sessionNeedsLogin: false,
            applied: credentials
        ) == nil
    )
    #expect(
        KeychainAutoFill.retainedCredentialsForReapply(
            sessionNeedsLogin: true,
            applied: nil
        ) == nil
    )
}
