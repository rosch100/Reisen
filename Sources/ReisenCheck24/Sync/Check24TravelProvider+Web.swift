import Foundation
import WebKit
import ReisenProviders

extension Check24TravelProvider {
    /// Hub-Session (`WebViewProviderSession`), kein Check24-Sondertyp.
    func webView(from session: any ProviderSession) throws -> WKWebView {
        try ProviderWebView.webView(from: session, orThrow: Check24ProviderError.invalidSessionType)
    }

    func load(url: URL, in webView: WKWebView) async throws {
        try await NavigationAwaiter().load(url, in: webView)
        try await Task.sleep(nanoseconds: 400_000_000)
    }

    func snapshotHTML(from webView: WKWebView) async throws -> (url: URL, html: String) {
        guard let pageURL = webView.url else { throw Check24ProviderError.snapshotFailed }
        let html = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML")
        guard let html else { throw Check24ProviderError.snapshotFailed }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            throw Check24ProviderError.snapshotFailed
        }
        let base = appSupport.appendingPathComponent("Reisen", isDirectory: true)
        let snapshots = base.appendingPathComponent("snapshots", isDirectory: true)
        try FileManager.default.createDirectory(at: snapshots, withIntermediateDirectories: true)
        let formatter = ISO8601DateFormatter()
        let fileName = "check24-\(formatter.string(from: Date())).html"
        let htmlURL = snapshots.appendingPathComponent(fileName)
        let metaURL = snapshots.appendingPathComponent(fileName + ".json")
        let meta: [String: Any] = [
            "createdAt": formatter.string(from: Date()),
            "pageURL": pageURL.absoluteString,
        ]
        try JSONSerialization.data(withJSONObject: meta, options: [.prettyPrinted]).write(to: metaURL, options: [.atomic])
        guard let htmlData = html.data(using: .utf8) else { throw Check24ProviderError.snapshotFailed }
        try htmlData.write(to: htmlURL, options: [.atomic])
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
