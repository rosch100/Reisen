import Foundation
import Testing
@testable import ReisenGetYourGuide

@Test func getYourGuideKeepsRegionalLoginAndEnglishSyncPaths() {
    #expect(GetYourGuideWebConstants.loginURL.absoluteString.contains("/de-de/customer-bookings/"))
    #expect(GetYourGuideWebConstants.catalogSyncURL.absoluteString.contains("/en-us/customer-bookings/"))
    #expect(GetYourGuideWebConstants.bookingURL(hash: "abc").contains("/en-us/booking/abc"))
    let normalized = GetYourGuideWebConstants.syncBookingURL(
        from: "https://www.getyourguide.com/de-de/booking/abc"
    )
    #expect(normalized?.absoluteString == "https://www.getyourguide.com/en-us/booking/abc")
    let withoutLocale = GetYourGuideWebConstants.syncBookingURL(
        from: "https://www.getyourguide.com/booking/abc"
    )
    #expect(withoutLocale?.absoluteString == "https://www.getyourguide.com/en-us/booking/abc")
    let localeOnly = GetYourGuideWebConstants.syncBookingURL(
        from: "https://www.getyourguide.com/de-de"
    )
    #expect(localeOnly?.path == "/en-us")
    #expect(
        GetYourGuideWebConstants.syncBookingURL(from: "https://evil.example/booking/abc") == nil
    )
}

@Test func getYourGuideSyncUsesEnglishCatalogOnSameOriginAsLogin() throws {
    #expect(GetYourGuideWebConstants.loginURL.host == GetYourGuideWebConstants.catalogSyncURL.host)
    #expect(GetYourGuideWebConstants.loginLocalePath == "de-de")
    #expect(GetYourGuideWebConstants.syncLocalePath == "en-us")
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_redacted.json")
    let html = "<html><script>window.__INITIAL_STATE__ = \(json);</script></html>"
    let stateJSON = try #require(GetYourGuideInitialState.extractJSONObject(fromHTML: html))
    let catalog = try GetYourGuideMyBookingsParser.parse(from: stateJSON)
    #expect(catalog.bookings.first?.externalUrl?.contains("/en-us/booking/") == true)
}
