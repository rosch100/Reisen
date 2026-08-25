import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class TravelokaTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .traveloka }
    public var displayName: String { "Traveloka" }

    public var loginURL: URL { TravelokaAPI.loginURL }
    public var keychainServerHost: String { "traveloka.com" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try extractWebView(from: session)
        let context = try await requireSessionContext(from: webView)
        let referer = TravelokaAPI.myBookingURL(routePrefix: context.resolvedRoutePrefix).absoluteString

        var byFingerprint: [String: ProviderBookingDraft] = [:]
        for status in TravelokaAPI.catalogItineraryStatuses {
            onProgress?("Lade Buchungen (Traveloka \(status))…")
            let drafts = try await fetchCatalogPage(
                webView: webView,
                context: context,
                status: status,
                referer: referer
            )
            for draft in drafts {
                let key = draft.rawPayloadFingerprint ?? draft.externalUrl ?? UUID().uuidString
                byFingerprint[key] = draft
            }
        }

        onProgress?("Parser Buchungen (Traveloka)…")
        return ProviderCatalog(bookings: byFingerprint.values.sorted { $0.startAt < $1.startAt })
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try extractWebView(from: session)
        let ids = try TravelokaExternalURL.detailIds(from: ref.externalUrl)
        let context = try await requireSessionContext(from: webView)

        onProgress?("Lade Buchungsdetails (Traveloka)…")
        let text = try await postJSON(
            webView: webView,
            url: TravelokaAPI.itinerariesSingleURL,
            referer: ref.externalUrl,
            body: try TravelokaAPI.singleBody(
                bookingId: ids.bookingId,
                itineraryId: ids.itineraryId,
                context: context
            ),
            context: context
        )

        onProgress?("Parser Buchungsdetails (Traveloka)…")
        let enrichment = try TravelokaEnrichmentParser.parse(from: text)
        guard enrichment.deadlines.isEmpty, let productType = ids.productType else {
            return enrichment
        }
        return await mergeRefundDeadlinesIfNeeded(
            enrichment: enrichment,
            webView: webView,
            context: context,
            productType: productType,
            bookingId: ids.bookingId,
            itineraryId: ids.itineraryId,
            referer: ref.externalUrl,
            timeZoneIdentifier: TravelokaEnrichmentParser.timeZoneIdentifier(from: text)
        )
    }
}

private extension TravelokaTravelProvider {
    func extractWebView(from session: any ProviderSession) throws -> WKWebView {
        guard let web = (session as? WebViewProviderSession)?.webView else {
            throw TravelokaProviderError.missingWebViewSession
        }
        return web
    }

    func requireSessionContext(from webView: WKWebView) async throws -> TravelokaSessionContext {
        let context = await webView.travelokaSessionContext()
        guard context.hasSentinel else {
            onProgress?("Traveloka-Session ohne Sentinel (sen_t) — bitte neu anmelden.")
            throw TravelokaProviderError.missingSessionSentinel
        }
        return context
    }

    func fetchCatalogPage(
        webView: WKWebView,
        context: TravelokaSessionContext,
        status: String,
        referer: String
    ) async throws -> [ProviderBookingDraft] {
        let text = try await postJSON(
            webView: webView,
            url: TravelokaAPI.itinerariesFetchURL,
            referer: referer,
            body: try TravelokaAPI.catalogFetchBody(
                itineraryTypes: TravelokaAPI.catalogItineraryTypes,
                itineraryStatus: status,
                context: context
            ),
            context: context
        )
        return try TravelokaCatalogParser.parse(from: text).bookings
    }

    func postJSON(
        webView: WKWebView,
        url: URL,
        referer: String,
        body: Data,
        context: TravelokaSessionContext
    ) async throws -> String {
        try await webView.fetchAuthenticatedText(
            url: url,
            method: "POST",
            accept: "application/json",
            referer: referer,
            contentType: "application/json",
            body: body,
            headers: TravelokaAPI.tripItineraryHeaders(referer: referer, context: context)
        )
    }

    func mergeRefundDeadlinesIfNeeded(
        enrichment: ProviderBookingEnrichment,
        webView: WKWebView,
        context: TravelokaSessionContext,
        productType: String,
        bookingId: String,
        itineraryId: String,
        referer: String,
        timeZoneIdentifier: String?
    ) async -> ProviderBookingEnrichment {
        onProgress?("Lade Storno-Fristen (Traveloka Refund)…")
        let refundURL = TravelokaAPI.refundPresubmissionURL(
            productType: productType,
            bookingId: bookingId,
            itineraryId: itineraryId,
            routePrefix: context.resolvedRoutePrefix
        )

        let html: String
        do {
            html = try await webView.fetchAuthenticatedText(
                url: refundURL,
                accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                referer: referer
            )
        } catch {
            onProgress?("Traveloka Refund-Seite nicht erreichbar — Detail ohne Fristen belassen.")
            return enrichment
        }

        guard let timeZone = TravelokaJSON.timeZone(iana: timeZoneIdentifier) else {
            onProgress?("Traveloka Refund ohne IANA-Zeitzone — Fristen nicht übernommen.")
            return enrichment
        }

        do {
            let deadlines = try TravelokaRefundPresubmissionParser.deadlines(
                fromHTML: html,
                timeZone: timeZone
            )
            guard !deadlines.isEmpty else {
                onProgress?("Traveloka Refund ohne Storno-Fristen im HTML.")
                return enrichment
            }
            var merged = enrichment
            merged.deadlines = deadlines
            return merged
        } catch {
            onProgress?("Traveloka Refund-Fristen nicht lesbar — Detail ohne Fristen belassen.")
            return enrichment
        }
    }
}
