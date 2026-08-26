import Testing
@testable import ReisenProviders

@Test func providerSyncLocaleUsesEnglishAndEUR() {
    #expect(ProviderSyncLocale.language == "en")
    #expect(ProviderSyncLocale.currency == "EUR")
}
