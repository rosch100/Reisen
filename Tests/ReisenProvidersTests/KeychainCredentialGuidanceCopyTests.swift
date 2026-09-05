import Testing
import Foundation
import ReisenDomain
import ReisenProviders

@Test func keychainNoReadableAccountGuidance_matchesRememberLoginActionLabel() {
    let locale = Locale(identifier: "de_DE")
    let message = L10n.withLocale(locale) {
        KeychainCredentialStore.CredentialStoreError.noEntry(serverHost: "airbnb.de").errorDescription
    }
    let action = L10n.withLocale(locale) {
        L10n.string(.actionRememberLogin)
    }
    let required = message
    #expect(required != nil)
    #expect(required!.contains(action))
    #expect(!required!.contains("Konto speichern"))
}

@Test func keychainAccountsFoundGuidance_matchesRememberLoginActionLabel() {
    let locale = Locale(identifier: "de_DE")
    let (message, action) = L10n.withLocale(locale) {
        (
            L10n.format(
                .syncKeychainAccountsFound,
                2,
                "booking.com",
                L10n.string(.actionRememberLogin)
            ),
            L10n.string(.actionRememberLogin)
        )
    }
    #expect(message.contains(action))
    #expect(!message.contains("Konto speichern"))
}
