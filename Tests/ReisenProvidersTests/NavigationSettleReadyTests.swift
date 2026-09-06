import Testing
import Foundation
import ReisenProviders

@MainActor
struct NavigationSettleReadyTests {
    private let bookingURL = URL(string: "https://hotel.check24.de/kundenbereich/buchung/abc")!

    @Test func onTargetStillLoading_isNotSettledImmediately() {
        let webView = FakeNavigationWebView(url: bookingURL, isLoading: true)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true
            ) == false
        )
    }

    @Test func onTargetStillLoading_afterGrace_isSettled() {
        let webView = FakeNavigationWebView(url: bookingURL, isLoading: true)
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true,
                onTargetSince: start,
                now: start.addingTimeInterval(2.0)
            )
        )
    }

    @Test func onTargetStillLoading_beforeGrace_isNotSettled() {
        let webView = FakeNavigationWebView(url: bookingURL, isLoading: true)
        let start = Date(timeIntervalSince1970: 1_000)
        #expect(
            NavigationSettleReady.isSettled(
                webView: webView,
                targetHost: "hotel.check24.de",
                targetPath: "/kundenbereich/buchung/abc",
                sawLoading: true,
                onTargetSince: start,
                now: start.addingTimeInterval(0.5)
            ) == false
        )
    }
}
