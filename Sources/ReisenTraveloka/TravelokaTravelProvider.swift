import Foundation
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

@MainActor
public final class TravelokaTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .traveloka }
    public var displayName: String { "Traveloka" }

    public var loginURL: URL { TravelokaAPI.loginURL }
    public var keychainServerHost: String { "traveloka.com" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: TravelokaProviderError.missingWebViewSession
        )
        let context = try await requireSessionContext(from: session)
        let referer = context.apiReferer()

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

    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        TravelokaDraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: TravelokaProviderError.missingWebViewSession
        )
        let ids = try TravelokaExternalURL.detailIds(from: ref.externalUrl)
        let context = try await requireSessionContext(from: session)

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
        guard let productType = ids.productType else {
            return enrichment
        }
        // Refund-HTML liefert Fee-Beträge, die im Itinerary oft fehlen.
        if enrichment.deadlines.contains(where: { !$0.isFreeCancellation }) {
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
    func requireSessionContext(from session: any ProviderSession) async throws -> TravelokaSessionContext {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: TravelokaProviderError.missingWebViewSession
        )
        let hintURLs = (session as? WebViewProviderSession)?.navigationHintURLs ?? []
        let context = await webView.travelokaSessionContext(additionalHintURLs: hintURLs)
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
        return try TravelokaCatalogParser.parse(
            from: text,
            routePrefix: context.resolvedRoutePrefix
        ).bookings
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
        } catch let error as AuthenticatedFetchError {
            switch error {
            case .httpStatus(let code) where code == 401 || code == 403:
                onProgress?("Traveloka Refund: Session abgelaufen — bitte neu anmelden.")
                Self.recordRefundSkipped(reason: "session_expired")
            case .httpStatus, .emptyBody, .timedOut:
                onProgress?("Traveloka Refund-Seite nicht erreichbar — Detail ohne Fristen belassen.")
                Self.recordRefundSkipped(reason: "refund_page_unreachable")
            }
            return enrichment
        } catch {
            onProgress?("Traveloka Refund-Seite nicht erreichbar — Detail ohne Fristen belassen.")
            Self.recordRefundSkipped(reason: "refund_fetch_failed")
            return enrichment
        }

        guard let timeZone = TravelokaJSON.timeZone(iana: timeZoneIdentifier) else {
            onProgress?("Traveloka Refund ohne IANA-Zeitzone — Fristen nicht übernommen.")
            Self.recordRefundSkipped(reason: "missing_iana_timezone")
            return enrichment
        }

        do {
            let deadlines = try TravelokaRefundPresubmissionParser.deadlines(
                fromHTML: html,
                timeZone: timeZone
            )
            guard !deadlines.isEmpty else {
                onProgress?("Traveloka Refund ohne Storno-Fristen im HTML.")
                Self.recordRefundSkipped(reason: "empty_refund_deadlines")
                return enrichment
            }
            var merged = enrichment
            merged.deadlines = enrichment.deadlines.combining(refund: deadlines)
            return merged
        } catch {
            onProgress?("Traveloka Refund-Fristen nicht lesbar — Detail ohne Fristen belassen.")
            Self.recordRefundSkipped(reason: "refund_parse_failed")
            return enrichment
        }
    }

    private static func recordRefundSkipped(reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .traveloka,
                        operation: "traveloka_enrich_refund"
                    ),
                    component: "TravelokaTravelProvider",
                    phase: "refund",
                    event: "refund_enrich_skipped",
                    result: .skipped,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
