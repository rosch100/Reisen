import Foundation
import ReisenDomain
import Testing
@testable import ReisenProviders

@Test func providerSyncLocaleUsesEnglishLanguage() {
    #expect(ProviderSyncLocale.language == "en")
}

@Test func providerSyncLocaleCurrency_usesPreferredFromDefaults() {
    let suite = "ReisenTests.ProviderSyncLocale.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    AppSettingsKeys.setPreferredCurrency("usd", defaults: defaults)
    #expect(ProviderSyncLocale.currency(defaults: defaults) == "USD")
}

@Test func providerSyncLocaleCurrency_fallsBackToLocaleThenDefault() {
    let suite = "ReisenTests.ProviderSyncLocale.fallback.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }

    let locale = Locale(identifier: "de_DE")
    #expect(ProviderSyncLocale.currency(defaults: defaults, locale: locale) == "EUR")
    #expect(ProviderSyncLocale.defaultCurrency == CurrencyCode.fallback)
}
