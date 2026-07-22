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
            #expect(err.domain == "NavigationAwaiter")
            #expect(err.code == 1)
        }

        #expect(!webView.loadRequests.isEmpty)
        #expect(webView.loadRequests.first?.url == targetURL)
    }
}

