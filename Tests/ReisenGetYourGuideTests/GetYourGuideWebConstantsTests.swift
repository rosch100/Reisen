import Foundation
import Testing
@testable import ReisenGetYourGuide

@Test func getYourGuideKeepsRegionalLoginAndEnglishSyncPaths() {
    #expect(GetYourGuideWebConstants.loginURL.path == "/login")
    #expect(GetYourGuideWebConstants.cookieHost == "getyourguide.com")
    let next = "next=/\(GetYourGuideWebConstants.loginLocalePath)/\(GetYourGuideWebConstants.bookingsPath)/"
    #expect(GetYourGuideWebConstants.loginURL.query?.contains(next) == true)
    #expect(GetYourGuideWebConstants.catalogSyncURL.absoluteString.contains("/\(GetYourGuideWebConstants.syncLocalePath)/\(GetYourGuideWebConstants.bookingsPath)/"))
    #expect(GetYourGuideWebConstants.bookingURL(hash: "abc").contains("/\(GetYourGuideWebConstants.syncLocalePath)/booking/abc"))
    let origin = GetYourGuideWebConstants.origin
    let sync = GetYourGuideWebConstants.syncLocalePath
    let normalized = GetYourGuideWebConstants.syncBookingURL(
        from: "\(origin)/de-de/booking/abc"
    )
    #expect(normalized?.absoluteString == "\(origin)/\(sync)/booking/abc")
    let withoutLocale = GetYourGuideWebConstants.syncBookingURL(
        from: "\(origin)/booking/abc"
    )
    #expect(withoutLocale?.absoluteString == "\(origin)/\(sync)/booking/abc")
    let localeOnly = GetYourGuideWebConstants.syncBookingURL(
        from: "\(origin)/\(GetYourGuideWebConstants.loginLocalePath)"
    )
    #expect(localeOnly?.path == "/\(sync)")
    #expect(
        GetYourGuideWebConstants.syncBookingURL(from: "https://evil.example/booking/abc") == nil
    )
}

@Test func getYourGuideSyncUsesEnglishCatalogOnSameOriginAsLogin() throws {
    #expect(GetYourGuideWebConstants.loginURL.host == GetYourGuideWebConstants.catalogSyncURL.host)
    #expect(GetYourGuideWebConstants.loginLocalePath == "de-de")
    #expect(GetYourGuideWebConstants.syncLocalePath == "en-us")
    let json = try GetYourGuideResearchFixture.json(named: "gyg_myBookings_redacted.json")
    let html = GetYourGuideResearchFixture.initialStateHTML(json)
    let stateJSON = try #require(GetYourGuideInitialState.extractJSONObject(fromHTML: html))
    let catalog = try GetYourGuideMyBookingsParser.parse(from: stateJSON)
    #expect(catalog.bookings.first?.externalUrl?.contains("/\(GetYourGuideWebConstants.syncLocalePath)/booking/") == true)
}
