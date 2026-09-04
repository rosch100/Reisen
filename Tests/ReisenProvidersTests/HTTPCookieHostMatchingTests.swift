import Foundation
import Testing
import ReisenProviders

@Test func httpCookieHostMatching_allowsExactAndSubdomain() {
    let cookie = HTTPCookie(properties: [
        .domain: "check24.de",
        .path: "/",
        .name: "session",
        .value: "secret",
    ])!
    let exact = URL(string: "https://check24.de/account")!
    let sub = URL(string: "https://kundenbereich.check24.de/login")!
    #expect(HTTPCookieHostMatching.matches(cookie, url: exact))
    #expect(HTTPCookieHostMatching.matches(cookie, url: sub))
}

@Test func httpCookieHostMatching_rejectsSuffixWithoutDotBoundary() {
    let cookie = HTTPCookie(properties: [
        .domain: "check24.de",
        .path: "/",
        .name: "session",
        .value: "secret",
    ])!
    let evil = URL(string: "https://evilcheck24.de/")!
    #expect(!HTTPCookieHostMatching.matches(cookie, url: evil))
}

@Test func httpCookieHostMatching_trimsLeadingDotOnCookieDomain() {
    let cookie = HTTPCookie(properties: [
        .domain: ".booking.com",
        .path: "/",
        .name: "session",
        .value: "secret",
    ])!
    let host = URL(string: "https://secure.booking.com/book")!
    #expect(HTTPCookieHostMatching.matches(cookie, url: host))
}
