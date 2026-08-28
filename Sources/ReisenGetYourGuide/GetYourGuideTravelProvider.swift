import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class GetYourGuideTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .getYourGuide }
    public var displayName: String { GetYourGuideWebConstants.displayName }

    public var loginURL: URL {
        GetYourGuideWebConstants.loginURL
    }

    public var keychainServerHost: String { GetYourGuideWebConstants.cookieHost }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        try await fetchParsed(
            from: session,
            url: GetYourGuideWebConstants.catalogSyncURL,
            subject: "Buchungen",
            parse: GetYourGuideMyBookingsParser.parse
        )
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        guard !ref.externalUrl.isEmpty,
              let url = GetYourGuideWebConstants.syncBookingURL(from: ref.externalUrl)
        else {
            throw GetYourGuideProviderError.invalidBookingURL
        }
        return try await fetchParsed(
            from: session,
            url: url,
            subject: "Buchungsdetails",
            parse: GetYourGuideBookingSummaryParser.parse
        )
    }
}

private extension GetYourGuideTravelProvider {
    func fetchParsed<T>(
        from session: any ProviderSession,
        url: URL,
        subject: String,
        parse: (String) throws -> T
    ) async throws -> T {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: GetYourGuideProviderError.missingWebViewSession
        )
        reportProgress("Lade", subject)
        let html = try await fetchBookingHTML(using: webView, url: url)
        guard let stateJSON = GetYourGuideInitialState.extractJSONObject(fromHTML: html) else {
            throw GetYourGuideProviderError.initialStateNotFound
        }
        reportProgress("Parser", subject)
        return try parse(stateJSON)
    }

    func reportProgress(_ action: String, _ subject: String) {
        onProgress?("\(action) \(subject) (\(displayName))…")
    }

    func fetchBookingHTML(using webView: WKWebView, url: URL) async throws -> String {
        do {
            return try await webView.fetchAuthenticatedHTML(
                url: url,
                referer: url.absoluteString,
                isLoginHTML: GetYourGuideInitialState.looksLikeLoginHTML,
                isChallengeHTML: GetYourGuideInitialState.looksLikeCloudflareChallenge
            )
        } catch let error as AuthenticatedSessionError {
            throw GetYourGuideProviderError.from(error)
        }
    }
}
