import Foundation
import Testing
import ReisenDomain

@Test func bookingExternalURL_manualPrefix_isSSOT() {
    #expect(BookingExternalURL.manualPrefix == "reisen://manual/")
}

@Test func bookingExternalURL_makeManual_usesPrefix() {
    let url = BookingExternalURL.makeManual()
    #expect(url.hasPrefix(BookingExternalURL.manualPrefix))
    #expect(BookingExternalURL.browserURL(from: url) == nil)
}

@Test func bookingExternalURL_browserURL_acceptsHttp() {
    let url = BookingExternalURL.browserURL(from: "https://example.com/booking/1")
    #expect(url?.absoluteString == "https://example.com/booking/1")
}

@Test func bookingExternalURL_browserURL_rejectsEmptyAndWhitespace() {
    #expect(BookingExternalURL.browserURL(from: nil) == nil)
    #expect(BookingExternalURL.browserURL(from: "") == nil)
    #expect(BookingExternalURL.browserURL(from: "   ") == nil)
}

@Test func bookingExternalURL_browserURL_rejectsDangerousSchemes() {
    #expect(BookingExternalURL.browserURL(from: "javascript:alert(1)") == nil)
    #expect(BookingExternalURL.browserURL(from: "file:///etc/passwd") == nil)
    #expect(BookingExternalURL.browserURL(from: "data:text/html,hi") == nil)
    #expect(BookingExternalURL.browserURL(from: "booking://open") == nil)
}

@Test func bookingExternalURL_isValidStoredURL_allowsManualAndHttps() {
    #expect(BookingExternalURL.isValidStoredURL(BookingExternalURL.makeManual()))
    #expect(BookingExternalURL.isValidStoredURL("https://example.com/x"))
    #expect(!BookingExternalURL.isValidStoredURL("javascript:alert(1)"))
    #expect(!BookingExternalURL.isValidStoredURL(""))
}
