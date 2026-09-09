import Foundation
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

@MainActor
public final class ExpediaTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .expedia }
    public var displayName: String { ProviderID.expedia.displayName }

    public var loginURL: URL { ExpediaAPI.loginURL }
    public var keychainServerHost: String { ExpediaAPI.portalHost }
    public var passwordAutofillAllowedHosts: [String] { [ExpediaAPI.portalHost, "www.\(ExpediaAPI.portalHost)"] }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let diagnosticContext = DiagnosticContext.current
            ?? DiagnosticContext(runID: UUID(), providerID: id, operation: "catalog")

        await record(
            context: diagnosticContext,
            phase: "catalog",
            event: "started",
            result: .started
        )

        do {
            let webView = try requireWebView(session)
            try await requireAuthenticatedSession(webView: webView)
            let duaid = try await requireDUAID(webView: webView)

            await record(
                context: diagnosticContext,
                phase: "login",
                event: "session_ready",
                result: .succeeded
            )

            onProgress?("Lade Reisen (Expedia.de)…")
            let tripsHTML = try await webView.fetchAuthenticatedHTML(
                url: ExpediaAPI.tripsURL,
                referer: ExpediaAPI.origin + "/",
                isLoginHTML: { ExpediaSessionProbe.isLoginHTML($0) }
            )
            let tripIDs = ExpediaTripsListParser.tripViewIDs(fromHTML: tripsHTML)
            guard !tripIDs.isEmpty else {
                await record(
                    context: diagnosticContext,
                    phase: "catalog",
                    event: "completed",
                    result: .succeeded,
                    reason: "empty_trip_list"
                )
                return ProviderCatalog(bookings: [])
            }

            var all: [ProviderBookingDraft] = []
            for tripViewId in tripIDs {
                onProgress?("Lade Buchungen (\(tripViewId.prefix(12))…)…")
                let data = try await postPersistedGraphQL(
                    webView: webView,
                    operation: ExpediaGraphQL.tripItems,
                    variables: [
                        "tripId": tripViewId,
                        "groups": [
                            ["filters": [["type": "STATUS", "value": "BOOKED"]]],
                        ],
                        "context": ExpediaGraphQL.context(duaid: duaid),
                    ],
                    referer: "\(ExpediaAPI.origin)/trips/\(tripViewId)"
                )
                let drafts = await ExpediaCatalogParser.drafts(
                    fromTripItemsData: data,
                    tripViewId: tripViewId,
                    diagnosticContext: diagnosticContext
                )
                all.append(contentsOf: drafts)
            }

            await record(
                context: diagnosticContext,
                phase: "catalog",
                event: "completed",
                result: .succeeded,
                reason: "count_\(all.count)"
            )
            return ProviderCatalog(bookings: all).dedupedByExternalURL()
        } catch {
            await recordPrimaryFailure(context: diagnosticContext, phase: "catalog", error: error)
            throw error
        }
    }

    public func needsDraftEnrichment(
        draft: ProviderBookingDraft,
        requiresDeadlines: Bool
    ) -> Bool {
        ExpediaDraftEnrichmentNeeds.shouldEnrich(draft, requiresDeadlines: requiresDeadlines)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let diagnosticContext = DiagnosticContext.current
            ?? DiagnosticContext(runID: UUID(), providerID: id, operation: "enrich")

        await record(
            context: diagnosticContext,
            phase: "enrich",
            event: "started",
            result: .started
        )

        do {
            let webView = try requireWebView(session)
            try await requireAuthenticatedSession(webView: webView)
            guard let parts = ExpediaExternalURL.parts(from: ref.externalUrl) else {
                throw ExpediaProviderError.missingTripItemId
            }
            let duaid = try await requireDUAID(webView: webView)
            onProgress?("Lade Buchungsdetails (Expedia.de)…")

            let tripData = try await postPersistedGraphQL(
                webView: webView,
                operation: ExpediaGraphQL.tripItem,
                variables: [
                    "item": [
                        "tripItemId": parts.tripItemId,
                        "tripViewId": parts.tripViewId,
                        "filter": NSNull(),
                    ],
                    "context": ExpediaGraphQL.context(duaid: duaid),
                ],
                referer: ref.externalUrl
            )

            var enrichment = ExpediaEnrichmentParser.enrichment(
                fromTripItemData: tripData,
                bookingType: ref.bookingType,
                externalUrl: ref.externalUrl,
                cancellationUrl: defaultCancellationURL(for: ref.bookingType, parts: parts)
            )

            if ref.bookingType == .hotel {
                enrichment = try await enrichHotel(
                    enrichment: enrichment,
                    webView: webView,
                    parts: parts,
                    duaid: duaid,
                    referer: ref.externalUrl
                )
            }

            await record(
                context: diagnosticContext,
                phase: "enrich",
                event: "completed",
                result: .succeeded
            )
            return enrichment
        } catch {
            await recordPrimaryFailure(context: diagnosticContext, phase: "enrich", error: error)
            throw error
        }
    }
}

private extension ExpediaTravelProvider {
    func requireWebView(_ session: any ProviderSession) throws -> WKWebView {
        try ProviderWebView.webView(
            from: session,
            orThrow: ExpediaProviderError.missingWebViewSession
        )
    }

    func requireAuthenticatedSession(webView: WKWebView) async throws {
        let loggedIn = try await ExpediaSessionProbe.fetchIsLoggedIn(using: webView)
        guard loggedIn == true else {
            throw ExpediaProviderError.sessionNotAuthenticated
        }
    }

    func requireDUAID(webView: WKWebView) async throws -> String {
        let cookies = await webView.allHTTPCookies()
        guard let duaid = ExpediaSessionProbe.duaid(from: cookies) else {
            throw ExpediaProviderError.missingDUAID
        }
        return duaid
    }

    func defaultCancellationURL(
        for bookingType: BookingType,
        parts: ExpediaExternalURL.Parts
    ) -> String? {
        guard ExpediaProductType.usesManageBookingAsCancellationURL(bookingType) else {
            return nil
        }
        return ExpediaExternalURL.manageBookingURL(
            tripViewId: parts.tripViewId,
            tripItemId: parts.tripItemId
        )
    }

    func enrichHotel(
        enrichment: ProviderBookingEnrichment,
        webView: WKWebView,
        parts: ExpediaExternalURL.Parts,
        duaid: String,
        referer: String?
    ) async throws -> ProviderBookingEnrichment {
        var result = enrichment
        result = try await applyRoomDetails(
            to: result,
            webView: webView,
            parts: parts,
            duaid: duaid,
            referer: referer
        )
        return try await applyBookingServicing(
            to: result,
            webView: webView,
            parts: parts,
            duaid: duaid,
            referer: referer
        )
    }

    func applyRoomDetails(
        to enrichment: ProviderBookingEnrichment,
        webView: WKWebView,
        parts: ExpediaExternalURL.Parts,
        duaid: String,
        referer: String?
    ) async throws -> ProviderBookingEnrichment {
        var result = enrichment
        do {
            let room = try await postPersistedGraphQL(
                webView: webView,
                operation: ExpediaGraphQL.roomDetails,
                variables: [
                    "tripItemId": parts.tripItemId,
                    "tripViewId": parts.tripViewId,
                    "context": ExpediaGraphQL.context(duaid: duaid),
                ],
                referer: referer
            )
            let deadlines = ExpediaEnrichmentParser.cancellationDeadlines(fromRoomDetails: room)
            if !deadlines.isEmpty {
                result.deadlines = deadlines
            }
            if let roomCategory = ExpediaEnrichmentParser.roomCategory(fromRoomDetails: room) {
                var rate = result.rateDetails ?? BookingRateDetails()
                if rate.roomCategory == nil {
                    rate.roomCategory = roomCategory
                    result.rateDetails = rate
                }
            }
        } catch {
            switch ExpediaHotelSidePath.roomDetailsHandling(for: error) {
            case .softContinue:
                await recordEnrichSidePathFailure(phase: "room_details", error: error)
            case .hardFail:
                if !(error is CancellationError) {
                    await recordEnrichSidePathFailure(phase: "room_details", error: error)
                }
                throw error
            }
        }
        return result
    }

    func applyBookingServicing(
        to enrichment: ProviderBookingEnrichment,
        webView: WKWebView,
        parts: ExpediaExternalURL.Parts,
        duaid: String,
        referer: String?
    ) async throws -> ProviderBookingEnrichment {
        var result = enrichment
        guard let lodgingTripId = ExpediaExternalURL.lodgingServicingTripId(
            fromEncodedTripItemId: parts.tripItemId
        ) else {
            await recordEnrichSidePathFailure(
                phase: "booking_servicing",
                error: ExpediaProviderError.lodgingTripIdUndecodable,
                reason: "lodging_trip_id_undecodable"
            )
            // Keep TripItem enrichment; cancel URL remains best-effort.
            return result
        }

        do {
            let servicing = try await postPersistedGraphQL(
                webView: webView,
                operation: ExpediaGraphQL.bookingServicingManage,
                variables: [
                    "input": [
                        "lodgingInput": [
                            "orderLineId": NSNull(),
                            "tripId": lodgingTripId,
                        ],
                    ],
                    "context": ExpediaGraphQL.context(duaid: duaid),
                ],
                referer: referer
            )
            if let cancelURL = ExpediaEnrichmentParser.hotelCancellationURL(fromServicingData: servicing) {
                result.cancellationUrl = cancelURL
            } else {
                await recordEnrichSidePathFailure(
                    phase: "booking_servicing",
                    error: ExpediaProviderError.missingHotelCancellationURL,
                    reason: "cancel_url_absent"
                )
            }
            let servicingDeadlines = ExpediaEnrichmentParser.cancellationDeadlines(
                fromServicingData: servicing
            )
            if !servicingDeadlines.isEmpty {
                result.deadlines = servicingDeadlines
            }
            return result
        } catch {
            switch ExpediaHotelSidePath.roomDetailsHandling(for: error) {
            case .softContinue:
                await recordEnrichSidePathFailure(phase: "booking_servicing", error: error)
                return result
            case .hardFail:
                if !(error is CancellationError) {
                    await recordEnrichSidePathFailure(phase: "booking_servicing", error: error)
                }
                throw error
            }
        }
    }

    func record(
        context: DiagnosticContext,
        phase: String,
        event: String,
        result: DiagnosticResult,
        reason: String? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "ExpediaTravelProvider",
                phase: phase,
                event: event,
                result: result,
                reason: reason,
                visibility: .publicDiagnostic
            )
        )
    }

    func recordPrimaryFailure(
        context: DiagnosticContext,
        phase: String,
        error: Error
    ) async {
        if error is CancellationError {
            await record(
                context: context,
                phase: phase,
                event: "cancelled",
                result: .cancelled
            )
            return
        }
        await record(
            context: context,
            phase: phase,
            event: "failed",
            result: .failed,
            reason: String(describing: type(of: error))
        )
    }

    func recordEnrichSidePathFailure(
        phase: String,
        error: Error,
        reason: String? = nil
    ) async {
        await record(
            context: DiagnosticContext.current
                ?? DiagnosticContext(runID: UUID(), providerID: id, operation: "enrich"),
            phase: phase,
            event: "side_path_failed",
            result: .failed,
            reason: reason ?? String(describing: type(of: error))
        )
    }

    func postPersistedGraphQL(
        webView: WKWebView,
        operation: ExpediaGraphQL.PersistedOperation,
        variables: [String: Any],
        referer: String?
    ) async throws -> [String: Any] {
        let body = try ExpediaGraphQL.persistedBody(
            operation: operation,
            variables: variables
        )
        let text = try await webView.fetchAuthenticatedText(
            url: ExpediaAPI.graphqlURL,
            method: "POST",
            accept: "application/json",
            referer: referer,
            contentType: "application/json",
            body: body,
            headers: [
                "client-info": "trips-pwa,reisen,local",
                "x-page-id": operation.pageID,
                "x-hcom-origin-id": operation.pageID,
            ]
        )
        do {
            return try ExpediaGraphQL.decodeDataObject(from: text)
        } catch ExpediaProviderError.graphqlHashRejected {
            await record(
                context: DiagnosticContext.current
                    ?? DiagnosticContext(runID: UUID(), providerID: id, operation: "graphql"),
                phase: "graphql",
                event: "hash_rejected",
                result: .failed,
                reason: operation.name
            )
            throw ExpediaProviderError.graphqlHashRejected
        } catch ExpediaProviderError.graphqlErrors {
            await record(
                context: DiagnosticContext.current
                    ?? DiagnosticContext(runID: UUID(), providerID: id, operation: "graphql"),
                phase: "graphql",
                event: "graphql_errors",
                result: .failed,
                reason: operation.name
            )
            throw ExpediaProviderError.graphqlErrors
        }
    }
}
