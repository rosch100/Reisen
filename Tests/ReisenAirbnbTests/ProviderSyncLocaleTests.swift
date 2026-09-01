import Foundation
import ReisenDomain
import ReisenProviders
import Testing
@testable import ReisenAirbnb

@Test func airbnbGraphQLUsesCanonicalSyncLocaleAndPreferredCurrency() {
    let suite = "ReisenTests.AirbnbSyncCurrency.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    AppSettingsKeys.setPreferredCurrency("usd", defaults: defaults)
    let currency = ProviderSyncLocale.currency(defaults: defaults)
    #expect(currency == "USD")

    let listURL = AirbnbAPI.tripListQueryURL(currency: currency)
    let detailsURL = AirbnbAPI.tripDetailsQueryURL(relayTripIDBase64: "abc", currency: currency)
    #expect(listURL.absoluteString.contains("locale=\(ProviderSyncLocale.language)"))
    #expect(detailsURL.absoluteString.contains("locale=\(ProviderSyncLocale.language)"))
    #expect(!listURL.absoluteString.contains("locale=de"))
    #expect(listURL.absoluteString.contains("currency=USD"))
    #expect(detailsURL.absoluteString.contains("currency=USD"))
}

@Test func airbnbMoneyAmount_usesRequestedCurrencyWhenSymbolMissing() {
    let details = AirbnbMoneyAmount.rateDetails(
        from: "Total cost: 133.15",
        requestedCurrency: "USD"
    )
    #expect(details?.totalPriceAmount == 133.15)
    #expect(details?.totalPriceCurrency == "USD")
}

@Test func airbnbMoneyAmount_prefersSymbolOverRequested() {
    let details = AirbnbMoneyAmount.rateDetails(
        from: "Total cost: €133.15",
        requestedCurrency: "USD"
    )
    #expect(details?.totalPriceCurrency == "EUR")
}

@Test func airbnbMoneyAmount_dollarSignUsesRequestedCurrency() {
    let details = AirbnbMoneyAmount.rateDetails(
        from: "Total cost: $133.15",
        requestedCurrency: "CAD"
    )
    #expect(details?.totalPriceAmount == 133.15)
    #expect(details?.totalPriceCurrency == "CAD")
}
