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
}
