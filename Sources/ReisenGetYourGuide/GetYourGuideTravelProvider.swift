import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class GetYourGuideTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .getYourGuide }
    public var displayName: String { "GetYourGuide" }

    public var loginURL: URL {
        URL(string: "https://www.getyourguide.com/de-de/customer-bookings/")!
    }

    public var keychainServerHost: String { "getyourguide.com" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try extractWebView(from: session)

        onProgress?("Lade Buchungen (GetYourGuide)…")
        let html = try await webView.fetchAuthenticatedText(
            url: loginURL,
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: "https://www.getyourguide.com/"
        )

        guard let stateJSON = GetYourGuideInitialState.extractJSONObject(fromHTML: html) else {
            throw GetYourGuideProviderError.initialStateNotFound
        }

        onProgress?("Parser Buchungen (GetYourGuide)…")
        return try GetYourGuideMyBookingsParser.parse(from: stateJSON)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try extractWebView(from: session)
        guard let url = URL(string: ref.externalUrl), !ref.externalUrl.isEmpty else {
            throw GetYourGuideProviderError.invalidBookingURL
        }

        onProgress?("Lade Buchungsdetails (GetYourGuide)…")
        let html = try await webView.fetchAuthenticatedText(
            url: url,
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: loginURL.absoluteString
        )

        guard let stateJSON = GetYourGuideInitialState.extractJSONObject(fromHTML: html) else {
            throw GetYourGuideProviderError.initialStateNotFound
        }

        onProgress?("Parser Buchungsdetails (GetYourGuide)…")
        return try GetYourGuideBookingSummaryParser.parse(from: stateJSON)
    }
}

private extension GetYourGuideTravelProvider {
    func extractWebView(from session: any ProviderSession) throws -> WKWebView {
        if let web = (session as? WebViewProviderSession)?.webView {
            return web
        }
        throw GetYourGuideProviderError.missingWebViewSession
    }
}
