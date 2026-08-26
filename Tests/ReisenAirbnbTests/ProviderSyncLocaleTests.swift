import Testing
@testable import ReisenAirbnb
import ReisenProviders

@Test func airbnbGraphQLUsesCanonicalSyncLocale() {
    let listURL = AirbnbAPI.tripListQueryURL()
    let detailsURL = AirbnbAPI.tripDetailsQueryURL(relayTripIDBase64: "abc")
    #expect(listURL.absoluteString.contains("locale=\(ProviderSyncLocale.language)"))
    #expect(detailsURL.absoluteString.contains("locale=\(ProviderSyncLocale.language)"))
    #expect(!listURL.absoluteString.contains("locale=de"))
}
