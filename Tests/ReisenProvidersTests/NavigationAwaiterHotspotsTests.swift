import Testing
import Foundation
import WebKit
import ReisenProviders

final class FakeNavigationWebView: NavigationWebView {
    var url: URL?
    var isLoading: Bool

    private(set) var loadRequests: [URLRequest] = []

    init(url: URL?, isLoading: Bool) {
        self.url = url
        self.isLoading = isLoading
    }

    func load(_ request: URLRequest) -> WKNavigation? {
        loadRequests.append(request)
        return nil
    }
}

@MainActor
struct NavigationAwaiterHotspotsTests {
    @Test("NavigationAwaiter.load: early return wenn Ziel-URL bereits aktiv und nicht loading")
    func navigationAwaiterEarlyReturn_whenOnTargetAndNotLoading() async throws {
        let currentURL = URL(string: "https://www.booking.com/mytrips.de.html/")!
        let targetURL = URL(string: "https://booking.com/mytrips.de.html")!

        let webView = FakeNavigationWebView(url: currentURL, isLoading: false)
        let awaiter = NavigationAwaiter(timeoutSeconds: 0.05)

        try await awaiter.load(targetURL, in: webView)

        #expect(webView.loadRequests.isEmpty)
    }

    @Test("NavigationAwaiter.load: Timeout wirft NSError domain NavigationAwaiter")
    func navigationAwaiterTimeout_whenNotOnTarget() async throws {
        let currentURL = URL(string: "https://example.com/other")!
        let targetURL = URL(string: "https://www.booking.com/mytrips.de.html")!

        let webView = FakeNavigationWebView(url: currentURL, isLoading: false)
        let awaiter = NavigationAwaiter(timeoutSeconds: 0.05)

        do {
            try await awaiter.load(targetURL, in: webView)
            throw NSError(domain: "UnexpectedSuccess", code: 0)
        } catch {
            let err = error as NSError
            #expect(err.domain == NavigationSettleTimeout.errorDomain)
            #expect(err.code == NavigationSettleTimeout.errorCode)
            #expect(NavigationSettleTimeout.isTimeout(error))
        }

        #expect(!webView.loadRequests.isEmpty)
        #expect(webView.loadRequests.first?.url == targetURL)
    }

    @Test("NavigationAwaiter.load: on-target + isLoading endet nicht mit Timeout")
    func navigationAwaiterSucceeds_whenOnTargetButStillLoading() async throws {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        let awaiter = NavigationAwaiter(timeoutSeconds: 4)
        try await awaiter.load(url, in: webView)
        #expect(webView.loadRequests.count == 1)
    }

    @Test("NavigationSettleLoop: on-target bei überschrittener Deadline wirft nicht")
    func navigationSettleLoopSucceeds_whenOnTargetAtDeadline() async throws {
        let url = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!
        let webView = FakeNavigationWebView(url: url, isLoading: true)
        try await NavigationSettleLoop.wait(
            webView: webView,
            targetHost: "hotel.check24.de",
            targetPath: "/kundenbereich/buchung/abc",
            deadline: Date().addingTimeInterval(-0.01),
            timeoutURL: url
        )
    }
}

