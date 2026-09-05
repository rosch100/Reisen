import Foundation
import Testing
import WebKit
import ReisenAppCore
import ReisenDomain

/// Remount-Churn: ensureWebView darf pro Provider nur einmal create aufrufen.
@MainActor
@Test func providerSessionHub_ensureWebView_createsOnlyOnce() {
    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([.airbnb])

    var createCount = 0
    let first = hub.ensureWebView(.airbnb) {
        createCount += 1
        return WKWebView()
    }
    let second = hub.ensureWebView(.airbnb) {
        createCount += 1
        return WKWebView()
    }

    #expect(createCount == 1)
    #expect(first === second)
    #expect(hub.webView(for: .airbnb) === first)
}

@MainActor
@Test func providerSessionHub_ensureWebView_requiresEnabledSlot() {
    let hub = ProviderSessionHub()
    var createCount = 0
    let created = hub.ensureWebView(.booking) {
        createCount += 1
        return WKWebView()
    }
    #expect(created == nil)
    #expect(createCount == 0)
}

@MainActor
@Test func providerSessionHub_requestedLoginURL_survivesRemountSemantics() {
    let hub = ProviderSessionHub()
    hub.syncEnabledProviders([.airbnb])
    let login = URL(string: "https://www.airbnb.de/login")!

    hub.noteRequestedLoginURL(.airbnb, url: login)
    #expect(hub.requestedLoginURL(for: .airbnb) == login)

    // Gleicher Intent nach Coordinator-Remount: kein zweites Load nötig.
    #expect(hub.requestedLoginURL(for: .airbnb) == login)

    let next = URL(string: "https://www.airbnb.de/login?locale=de")!
    hub.noteRequestedLoginURL(.airbnb, url: next)
    #expect(hub.requestedLoginURL(for: .airbnb) == next)

    hub.updateWebView(.airbnb, webView: nil)
    #expect(hub.requestedLoginURL(for: .airbnb) == nil)
}
