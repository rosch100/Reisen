import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class GetYourGuideTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .getYourGuide }
    public var displayName: String { "GetYourGuide" }

    public var loginURL: URL {
        GetYourGuideWebConstants.loginURL
    }

    public var keychainServerHost: String { "getyourguide.com" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: GetYourGuideProviderError.missingWebViewSession
        )

        onProgress?("Lade Buchungen (GetYourGuide)…")
        let html = try await webView.fetchAuthenticatedText(
            url: GetYourGuideWebConstants.catalogSyncURL,
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: GetYourGuideWebConstants.catalogSyncURL.absoluteString
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
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: GetYourGuideProviderError.missingWebViewSession
        )
        guard !ref.externalUrl.isEmpty,
              let url = GetYourGuideWebConstants.syncBookingURL(from: ref.externalUrl)
        else {
            throw GetYourGuideProviderError.invalidBookingURL
        }

        onProgress?("Lade Buchungsdetails (GetYourGuide)…")
        let html = try await webView.fetchAuthenticatedText(
            url: url,
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: url.absoluteString
        )

        guard let stateJSON = GetYourGuideInitialState.extractJSONObject(fromHTML: html) else {
            throw GetYourGuideProviderError.initialStateNotFound
        }

        onProgress?("Parser Buchungsdetails (GetYourGuide)…")
        return try GetYourGuideBookingSummaryParser.parse(from: stateJSON)
    }
}
