import Foundation
import WebKit
import ReisenProviders

extension Check24TravelProvider {
    func webView(from session: any ProviderSession) throws -> WKWebView {
        guard let check24 = session as? Check24WebSession else {
            throw Check24ProviderError.invalidSessionType
        }
        return check24.webView
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
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return host.contains("hotel.check24.de") && path.contains("/kundenbereich/buchung/")
    }

    func isNonHotelBookingDetailURL(_ url: URL) -> Bool {
        let host = (url.host ?? "").lowercased()
        let path = url.path.lowercased()
        return (host.contains("flug.check24.de") || host.contains("ferry.check24.de"))
            && path.contains("/kundenbereich/buchung/")
    }
}
