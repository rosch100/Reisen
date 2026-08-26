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
