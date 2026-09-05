import Foundation
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenDiagnostics

@MainActor
public final class AirbnbTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .airbnb }
    public var displayName: String { "Airbnb" }

    public var loginURL: URL {
        URL(string: "https://www.airbnb.de/trips")!
    }

    public var keychainServerHost: String { "airbnb.de" }

    public var passwordAutofillAllowedHosts: [String] { ["airbnb.de", "airbnb.com"] }

    public var onProgress: (@MainActor (String) -> Void)?

    nonisolated static func isAirbnbHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        if host == "airbnb.com" || host.hasSuffix(".airbnb.com") { return true }
        if host == "airbnb.de" || host.hasSuffix(".airbnb.de") { return true }
        return host.range(
            of: #"(^|\.)airbnb\.(co\.)?[a-z]{2,}$"#,
            options: .regularExpression
        ) != nil
    }

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: RepositoryError.invalidState("Airbnb provider benötigt eine WKWebView-basierte Session.")
        )
        try await ensureOnAirbnbOrigin(using: webView)

        onProgress?("Lade Trips (Airbnb)…")
        let jsonText = try await fetchAirbnbText(
            webView: webView,
            url: AirbnbAPI.tripListQueryURL(),
            headers: graphqlHeaders(referer: loginURL.absoluteString)
        )

        onProgress?("Parser Trips (Airbnb)…")
        return try AirbnbTripsGraphQLParser.parseTripList(from: jsonText)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try ProviderWebView.webView(
            from: session,
            orThrow: RepositoryError.invalidState("Airbnb provider benötigt eine WKWebView-basierte Session.")
        )
        try await ensureOnAirbnbOrigin(using: webView)
        let (numericTripID, schedulableType, confirmationCode) = try parseExternalRef(externalUrl: ref.externalUrl)

        onProgress?("Lade Trip-Details (Airbnb)…")
        let relayTripID = try encodeTripRelayID(numericTripID)
        let tripDetailsText = try await fetchAirbnbText(
            webView: webView,
            url: AirbnbAPI.tripDetailsQueryURL(relayTripIDBase64: relayTripID),
            headers: graphqlHeaders(referer: loginURL.absoluteString)
        )

        let tripDetails = try AirbnbTripDetailsParser.parse(
            responseText: tripDetailsText,
            bookingType: ref.bookingType,
            confirmationCode: confirmationCode
        )

        if schedulableType.uppercased().contains("EXPERIENCE") {
            return try await enrichExperience(
                webView: webView,
                schedulableType: schedulableType,
                confirmationCode: confirmationCode,
                tripDetails: tripDetails
            )
        }

        onProgress?("Lade Reservation-Overview (Airbnb)…")
        let stayDetailsURL = reservationOverviewURL(
            pathPrefix: AirbnbAPI.stayReservationDetailsPathPrefix,
            schedulableType: schedulableType,
            confirmationCode: confirmationCode
        )
        let stayDetailsText = try await fetchAirbnbText(
            webView: webView,
            url: stayDetailsURL,
            headers: reservationOverviewHeaders(referer: loginURL.absoluteString)
        )

        let hotelOffsetSeconds: Int?
        if let offset = AirbnbListingTimeZone.offsetSeconds(
            listingTimeZone: tripDetails.listingTimeZone,
            at: tripDetails.tripStartAt
        ) {
            hotelOffsetSeconds = offset
        } else {
            Self.recordEnrichSkipped(
                reason: "invalid_listing_timezone",
                detail: tripDetails.listingTimeZone
            )
            hotelOffsetSeconds = nil
        }

        let scheduledParsed = try AirbnbScheduledEventsParser.parse(
            responseText: stayDetailsText,
            hotelOffsetSeconds: hotelOffsetSeconds
        )
        let guestHints = AirbnbGuestHintParser().parse(from: stayDetailsText)

        return DraftAssembler.enrichment(
            from: AirbnbStayEnrichment.facts(
                bookingType: ref.bookingType,
                tripDetails: tripDetails,
                scheduled: scheduledParsed,
                hotelOffsetSeconds: hotelOffsetSeconds,
                guestHints: guestHints
            )
        )
    }
}

extension AirbnbTravelProvider {
    fileprivate static func recordEnrichSkipped(reason: String, detail: String) {
        let sanitized = detail
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .prefix(64)
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .airbnb,
                        operation: "airbnb_enrich"
                    ),
                    component: "AirbnbTravelProvider",
                    phase: "timezone",
                    event: "enrich_skipped",
                    result: .skipped,
                    reason: "\(reason)_\(sanitized)",
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}

private extension AirbnbTravelProvider {
    func ensureOnAirbnbOrigin(using webView: WKWebView) async throws {
        let onAirbnb = Self.isAirbnbHost(webView.url?.host)
        if !onAirbnb {
            try await NavigationAwaiter().load(loginURL, in: webView)
        }
    }

    func graphqlHeaders(referer: String) -> [String: String] {
        [
            AirbnbAPI.apiKeyHeader: AirbnbAPI.apiKeyValue,
            AirbnbAPI.graphqlPlatformHeader: AirbnbAPI.graphqlPlatformValue,
            AirbnbAPI.graphqlPlatformClientHeader: AirbnbAPI.graphqlPlatformClientValue,
            AirbnbAPI.csrfWithoutTokenHeader: AirbnbAPI.csrfWithoutTokenValue,
            "Content-Type": "application/json",
            "Accept": "application/json",
            "Referer": referer,
        ]
    }

    func enrichExperience(
        webView: WKWebView,
        schedulableType: String,
        confirmationCode: String,
        tripDetails: AirbnbTripDetails
    ) async throws -> ProviderBookingEnrichment {
        onProgress?("Lade Experience-Details (Airbnb)…")
        let detailsURL = reservationOverviewURL(
            pathPrefix: AirbnbAPI.activityReservationDetailsPathPrefix,
            schedulableType: schedulableType,
            confirmationCode: confirmationCode
        )
        let detailsText = try await fetchAirbnbText(
            webView: webView,
            url: detailsURL,
            headers: reservationOverviewHeaders(referer: loginURL.absoluteString)
        )
        let parsed = try AirbnbActivityReservationDetailsParser.parse(
            responseText: detailsText,
            referenceDate: tripDetails.tripStartAt
        )

        let guestCount = ([parsed.guestAdults, tripDetails.guestAdults].compactMap { count -> Int? in
            guard let count, count > 0 else { return nil }
            return count
        }).first
        let rateDetails = BookingRateDetails.merging(
            existing: parsed.rateDetails,
            incoming: guestCount.map { BookingRateDetails(guestCount: $0) }
        )

        let hotelOffsetSeconds: Int?
        if let offset = AirbnbListingTimeZone.offsetSeconds(
            listingTimeZone: tripDetails.listingTimeZone,
            at: tripDetails.tripStartAt
        ) {
            hotelOffsetSeconds = offset
        } else {
            Self.recordEnrichSkipped(
                reason: "invalid_listing_timezone",
                detail: tripDetails.listingTimeZone
            )
            hotelOffsetSeconds = nil
        }

        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .airbnb,
                bookingType: .activity,
                title: parsed.title,
                locationTo: parsed.locationTo,
                locationToAddress: parsed.locationToAddress,
                statusRaw: tripDetails.reservationStatus,
                deadlines: parsed.deadlines,
                rateDetails: rateDetails,
                hotelOffsetSeconds: hotelOffsetSeconds
            )
        )
    }

    func reservationOverviewHeaders(referer: String) -> [String: String] {
        [
            AirbnbAPI.apiKeyHeader: AirbnbAPI.apiKeyValue,
            "Accept": "application/json",
            "Referer": referer,
        ]
    }

    /// Shared query params for Stay `stay_reservation_details` and Experience `activity_reservation_details`.
    func reservationOverviewURL(
        pathPrefix: String,
        schedulableType: String,
        confirmationCode: String,
        currency: String = ProviderSyncLocale.currency()
    ) -> URL {
        var comps = URLComponents(url: AirbnbAPI.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = "\(pathPrefix)/\(schedulableType)/\(confirmationCode)"
        comps.queryItems = [
            URLQueryItem(name: "locale", value: ProviderSyncLocale.language),
            URLQueryItem(name: "currency", value: currency),
            URLQueryItem(name: "include_header_action_rows", value: "true"),
            URLQueryItem(name: "_format", value: "for_generic_ro"),
            URLQueryItem(name: "translate_ugc", value: "false"),
        ]
        return comps.url!
    }

    func parseExternalRef(externalUrl: String) throws -> (numericTripID: String, schedulableType: String, confirmationCode: String) {
        // Expected:
        // https://www.airbnb.de/trips/v1/{numericTripID}/ro/{schedulableType}/{confirmationCode}
        let marker = "/trips/v1/"
        guard let idx = externalUrl.range(of: marker) else {
            throw RepositoryError.invalidState("Ungültiger Airbnb externalUrl (missing trips/v1).")
        }
        let afterMarker = externalUrl[idx.upperBound...]
        let parts = afterMarker.split(separator: "/")
        guard parts.count >= 4 else {
            throw RepositoryError.invalidState("Ungültiger Airbnb externalUrl (unexpected segment count).")
        }
        let numericTripID = String(parts[0])

        // ... /ro/{schedulableType}/{confirmationCode}
        guard parts[1] == "ro" else {
            throw RepositoryError.invalidState("Ungültiger Airbnb externalUrl (missing /ro/).")
        }
        let schedulableType = String(parts[2])
        let confirmationCode = String(parts[3])

        guard !numericTripID.isEmpty, !schedulableType.isEmpty, !confirmationCode.isEmpty else {
            throw RepositoryError.invalidState("Ungültiger Airbnb externalUrl (empty fields).")
        }
        return (numericTripID: numericTripID, schedulableType: schedulableType, confirmationCode: confirmationCode)
    }

    func encodeTripRelayID(_ numericTripID: String) throws -> String {
        let relayString = "Trip:\(numericTripID)"
        guard let data = relayString.data(using: .utf8) else {
            throw RepositoryError.invalidState("Trip relay id encode failed.")
        }
        return data.base64EncodedString()
    }

    func fetchAirbnbText(
        webView: WKWebView,
        url: URL,
        headers: [String: String]
    ) async throws -> String {
        do {
            return try await webView.airbnbFetchTextAsync(url: url, headers: headers)
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw AirbnbProviderError.sessionNotEstablished
        }
    }
}

