import Testing
import Foundation
import ReisenDomain
import ReisenProviders

@Test func providerNativeApp_queryURLSchemes_matchesCatalog() {
    #expect(ProviderNativeApp.queryURLSchemes == [
        "airbnb",
        "booking",
        "check24",
        "getyourguide",
        "gyg",
        "opodo",
        "traveloka",
    ])
}

@Test func providerNativeApp_urlSchemes_forKnownProviders() {
    #expect(ProviderNativeApp.urlSchemes(for: .booking) == ["booking"])
    #expect(ProviderNativeApp.urlSchemes(for: .airbnb) == ["airbnb"])
    #expect(ProviderNativeApp.urlSchemes(for: .getYourGuide) == ["getyourguide", "gyg"])
    #expect(ProviderNativeApp.urlSchemes(for: .manual) == nil)
}

@Test func providerWebViewNavigationPolicy_allowsStandardWebSchemes() {
    let url = URL(string: "https://secure.booking.com/login")!
    #expect(ProviderWebViewNavigationPolicy.allows(url, isMainFrame: true))
}

@Test func providerWebViewNavigationPolicy_cancelsCustomSchemes() {
    let url = URL(string: "booking://open")!
    #expect(!ProviderWebViewNavigationPolicy.allows(url, isMainFrame: true))
}

@Test func providerWebViewNavigationPolicy_cancelsAppStoreLinksOnMainFrame() {
    let url = URL(string: "https://apps.apple.com/de/app/booking-com/id367003269")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: true) == .cancel)
}

@Test func providerWebViewNavigationPolicy_cancelsItunesSubdomainOnMainFrame() {
    let url = URL(string: "https://geo.itunes.apple.com/de/app/booking-com/id367003269")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: true) == .cancel)
}

@Test func providerWebViewNavigationPolicy_allowsAppStoreLinksInSubframe() {
    let url = URL(string: "https://apps.apple.com/de/app/booking-com/id367003269")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: false) == .allow)
}

@Test func providerWebViewNavigationPolicy_cancelsItmsAppsScheme() {
    let url = URL(string: "itms-apps://apps.apple.com/app/id367003269")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: true) == .cancel)
}

@Test func providerWebViewNavigationPolicy_cancelsDataScheme() {
    let url = URL(string: "data:text/html,<script>1</script>")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: true) == .cancel)
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: false) == .cancel)
}

@Test func providerWebViewNavigationPolicy_cancelsBlobOnMainFrameOnly() {
    let url = URL(string: "blob:https://example.com/uuid")!
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: true) == .cancel)
    #expect(ProviderWebViewNavigationPolicy.decision(for: url, isMainFrame: false) == .allow)
}
