import Foundation
import WebKit
import ReisenDiagnostics
import ReisenProviders

extension Check24TravelProvider {
    func recordDiagnosticPhase(
        _ phase: String,
        event: String,
        result: DiagnosticResult,
        url: URL? = nil,
        reason: String? = nil
    ) async {
        guard let diagnosticContext = DiagnosticContext.current else { return }
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: diagnosticContext,
                component: "Check24TravelProvider",
                phase: phase,
                event: event,
                result: result,
                url: url?.absoluteString,
                reason: reason
            )
        )
    }

    /// Hub-Session (`WebViewProviderSession`), kein Check24-Sondertyp.
    func webView(from session: any ProviderSession) throws -> WKWebView {
        try ProviderWebView.webView(from: session, orThrow: Check24ProviderError.invalidSessionType)
    }

    func load(url: URL, in webView: WKWebView) async throws {
        try await NavigationAwaiter().load(
            url,
            in: webView,
            diagnosticContext: DiagnosticContext.current
        )
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func snapshotHTML(from webView: WKWebView) async throws -> (url: URL, html: String) {
        guard let pageURL = webView.url else { throw Check24ProviderError.snapshotFailed }
        let html = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML")
        guard let html else { throw Check24ProviderError.snapshotFailed }

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ReisenDiagnosticsDebug"),
           let diagnosticContext = DiagnosticContext.current {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "Check24TravelProvider",
                    phase: "dom",
                    event: "allowlist_features",
                    result: .succeeded,
                    url: pageURL.absoluteString,
                    reason: [
                        "activities=\(html.contains("activities"))",
                        "booking_info=\(html.contains("bookingInfo"))",
                        "third_view_data=\(html.contains("thirdViewData"))",
                        "basket=\(html.contains("basketContainer"))",
                    ].joined(separator: ","),
                    visibility: .localDebugOnly
                )
            )
        }
#endif
        return (url: pageURL, html: html)
    }

    func isHotelBookingDetailURL(_ url: URL) -> Bool {
        Check24BookingDetailURL.isHotelStayDetail(url)
    }

    func isNonHotelBookingDetailURL(_ url: URL) -> Bool {
        Check24BookingDetailURL.isFlightOrFerryDetail(url)
    }

    func isCarRentalBookingDetailURL(_ url: URL) -> Bool {
        Check24BookingDetailURL.isCarRentalDetail(url)
    }
}
