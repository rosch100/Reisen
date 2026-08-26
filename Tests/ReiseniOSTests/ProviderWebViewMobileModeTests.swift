import XCTest
import WebKit

@testable import ReiseniOS

@MainActor
final class ProviderWebViewMobileModeTests: XCTestCase {
    func testWebpagePreferencesRequestMobileContent() {
        let preferences = WKWebpagePreferences()
        ProviderWebViewMobileMode.apply(to: preferences)
        XCTAssertEqual(preferences.preferredContentMode, .mobile)
        XCTAssertTrue(preferences.allowsContentJavaScript)
    }

    func testUserAgentIdentifiesIPhoneNotDesktopOrIPad() {
        let ua = ProviderWebViewMobileMode.safariMobileUserAgent
        XCTAssertTrue(ua.contains("iPhone"))
        XCTAssertTrue(ua.contains("Mobile"))
        XCTAssertFalse(ua.contains("Macintosh"))
        XCTAssertFalse(ua.contains("iPad"))
    }
}
