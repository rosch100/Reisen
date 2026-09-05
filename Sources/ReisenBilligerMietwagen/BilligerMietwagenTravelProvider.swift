import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class BilligerMietwagenTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .billigerMietwagen }
    public var displayName: String { ProviderID.billigerMietwagen.displayName }

    public var loginURL: URL { BilligerMietwagenAuthConstants.loginPageURL }
    public var keychainServerHost: String { BilligerMietwagenAuthConstants.portalHost }

    public var onProgress: (@MainActor (String) -> Void)?

    /// Frischer Bearer für einen Sync-Lauf (Catalog + Enrich); kein Refresh pro Enrich.
    private var cachedAccessToken: String?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try requireWebView(session)
        cachedAccessToken = nil
        let headers = try await bearerHeaders(webView: webView)

        progress("Lade Buchungen")
        // Sequentiell auf derselben WKWebView/Cookie-Session (nicht parallel).
        var bookings: [ProviderBookingDraft] = []
        for list in BilligerMietwagenWebConstants.CatalogList.allCases {
            bookings.append(
                contentsOf: try await fetchAllBookingPages(
                    webView: webView,
                    headers: headers,
                    list: list
                )
            )
        }
        return ProviderCatalog(bookings: bookings).dedupedByExternalURL()
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try requireWebView(session)
        guard let bookingID = BilligerMietwagenWebConstants.bookingID(from: ref.externalUrl) else {
            throw BilligerMietwagenProviderError.invalidBookingURL
        }

        progress("Lade Buchungsdetails")
        let json = try await fetchJSON(
            webView: webView,
            url: BilligerMietwagenWebConstants.bookingDetailURL(id: bookingID),
            referer: ref.externalUrl,
            headers: try await bearerHeaders(webView: webView)
        )

        progress("Parser Buchungsdetails")
        return try BilligerMietwagenBookingDetailParser.parse(
            from: json,
            catalogStartAt: ref.referenceStartAt,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
    }

    private func requireWebView(_ session: any ProviderSession) throws -> WKWebView {
        try ProviderWebView.webView(
            from: session,
            orThrow: BilligerMietwagenProviderError.missingWebViewSession
        )
    }

    func progress(_ step: String) {
        onProgress?("\(step) (\(displayName))…")
    }

    func fetchJSON(
        webView: WKWebView,
        url: URL,
        referer: String?,
        headers: [String: String] = [:],
        method: String = "GET",
        contentType: String? = nil,
        body: Data? = nil
    ) async throws -> String {
        do {
            return try await webView.fetchAuthenticatedText(
                url: url,
                method: method,
                accept: "application/json",
                referer: referer,
                contentType: contentType,
                body: body,
                headers: headers
            )
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw BilligerMietwagenProviderError.sessionNotAuthenticated
        }
    }

    func postJSON(
        webView: WKWebView,
        url: URL,
        referer: String?,
        headers: [String: String] = [:],
        body: Data
    ) async throws -> String {
        try await fetchJSON(
            webView: webView,
            url: url,
            referer: referer,
            headers: headers,
            method: "POST",
            contentType: "application/json",
            body: body
        )
    }

    private func bearerHeaders(webView: WKWebView) async throws -> [String: String] {
        BilligerMietwagenAuthConstants.apiRequestHeaders(
            accessToken: try await resolvedAccessToken(webView: webView)
        )
    }

    private func resolvedAccessToken(webView: WKWebView) async throws -> String {
        if let cachedAccessToken {
            return cachedAccessToken
        }
        let token = try await requireAccessToken(webView: webView)
        cachedAccessToken = token
        return token
    }

    private func fetchAllBookingPages(
        webView: WKWebView,
        headers: [String: String],
        list: BilligerMietwagenWebConstants.CatalogList
    ) async throws -> [ProviderBookingDraft] {
        var page = 0
        var all: [ProviderBookingDraft] = []
        while page < BilligerMietwagenWebConstants.bookingListMaxPages {
            let json = try await fetchJSON(
                webView: webView,
                url: list.url(page: page),
                referer: BilligerMietwagenWebConstants.catalogReferer,
                headers: headers
            )
            let parsed = try BilligerMietwagenBookingsParser.parsePage(from: json, fetchedPage: page)
            all.append(contentsOf: parsed.bookings)
            guard let next = parsed.nextPage, next > page else {
                return all
            }
            page = next
        }
        throw BilligerMietwagenProviderError.catalogPaginationLimitExceeded
    }
}
