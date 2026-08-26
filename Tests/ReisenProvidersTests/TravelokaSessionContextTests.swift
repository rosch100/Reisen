import Foundation
import Testing
@testable import ReisenProviders

@Test func travelokaRoutePrefixExtractsFromLocalizedPath() {
    let url = URL(string: "https://www.traveloka.com/id-id/user/mybooking")!
    #expect(TravelokaRoutePrefix.extract(from: url) == "id-id")
}

@Test func travelokaRoutePrefixFromAPILanguage() {
    #expect(TravelokaRoutePrefix.fromAPILanguage("en_EN") == "en-en")
    #expect(TravelokaRoutePrefix.fromAPILanguage("id-ID") == "id-id")
}

@Test func travelokaSessionContextResolvesRouteFromNavigationHistory() {
    let signIn = URL(string: "https://www.traveloka.com/en-en/user/signin")!
    let home = URL(string: "https://www.traveloka.com/")!
    var context = TravelokaSessionContext.from(cookies: [])
    context.applyNavigationHints(from: [home, signIn])
    #expect(context.resolvedRoutePrefix == "en-en")
    #expect(context.bestPageURL == signIn)
}

@Test func travelokaSessionContextPrefersDetailPageAsReferer() {
    let home = URL(string: "https://www.traveloka.com/")!
    let signIn = URL(string: "https://www.traveloka.com/en-en/user/signin")!
    let detail = URL(string: "https://www.traveloka.com/en-en/item/details/1?type=HOTEL&id=2")!
    var context = TravelokaSessionContext.from(cookies: [])
    context.applyNavigationHints(from: [home, signIn, detail])
    #expect(context.bestPageURL == detail)
    #expect(context.apiReferer() == detail.absoluteString)
}

@Test func travelokaSessionContextApiRefererPrefersCurrentUserPage() {
    let detail = URL(string: "https://www.traveloka.com/en-en/item/details/1?type=HOTEL&id=2")!
    let context = TravelokaSessionContext(routePrefix: "en-en", bestPageURL: detail)
    #expect(context.apiReferer() == detail.absoluteString)
}

@Test func travelokaSessionContextApiRefererFallsBackToMyBooking() {
    let context = TravelokaSessionContext()
    #expect(context.apiReferer() == "https://www.traveloka.com/en-en/user/mybooking")
}

@Test func travelokaSessionContextIgnoresLocaleCookieForSyncHeaders() {
    let locale = HTTPCookie(properties: [
        .name: "locale",
        .value: "id_ID",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    let currency = HTTPCookie(properties: [
        .name: "selectedCurrency",
        .value: "IDR",
        .domain: ".traveloka.com",
        .path: "/",
    ])!
    let context = TravelokaSessionContext.from(cookies: [locale, currency])
    #expect(context.resolvedRoutePrefix == "en-en")
    #expect(context.resolvedLanguage == "en_EN")
    #expect(context.resolvedCountry == "EN")
    #expect(context.resolvedCurrency == "IDR")
    let headers = context.applying(to: [:])
    #expect(headers["x-route-prefix"] == "en-en")
    #expect(headers["tv-language"] == "en_EN")
    #expect(headers["tv-country"] == "EN")
}
