import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class AirbnbTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .airbnb }
    public var displayName: String { "Airbnb" }

    public var loginURL: URL {
        URL(string: "https://www.airbnb.de/trips")!
    }

    public var keychainServerHost: String { "airbnb.de" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try extractWebView(from: session)

        onProgress?("Lade Trips (Airbnb)…")
        let jsonText = try await webView.airbnbFetchTextAsync(
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
        let webView = try extractWebView(from: session)
        let (numericTripID, schedulableType, confirmationCode) = try parseExternalRef(externalUrl: ref.externalUrl)

        onProgress?("Lade Trip-Details (Airbnb)…")
        let relayTripID = try encodeTripRelayID(numericTripID)
        let tripDetailsText = try await webView.airbnbFetchTextAsync(
            url: AirbnbAPI.tripDetailsQueryURL(relayTripIDBase64: relayTripID),
            headers: graphqlHeaders(referer: loginURL.absoluteString)
        )

        let tripDetails = try AirbnbTripDetailsParser.parse(
            responseText: tripDetailsText,
            bookingType: ref.bookingType,
            confirmationCode: confirmationCode
        )

        let resolvedStatus: BookingStatus? = {
            guard let reservationStatus = tripDetails.reservationStatus else { return nil }
            let haystack = reservationStatus.lowercased()
            if haystack.contains("cancel") { return .cancelled }
            return .confirmed
        }()

        if schedulableType.uppercased().contains("EXPERIENCE") {
            return try await enrichExperience(
                webView: webView,
                schedulableType: schedulableType,
                confirmationCode: confirmationCode,
                tripDetails: tripDetails,
                resolvedStatus: resolvedStatus
            )
        }

        onProgress?("Lade Reservation-Overview (Airbnb)…")
        let scheduledEventsURL = reservationOverviewURL(
            pathPrefix: "/api/v2/scheduled_events",
            schedulableType: schedulableType,
            confirmationCode: confirmationCode
        )
        let scheduledEventsText = try await webView.airbnbFetchTextAsync(
            url: scheduledEventsURL,
            headers: scheduledEventsHeaders(referer: loginURL.absoluteString)
        )

        let scheduledParsed = try AirbnbScheduledEventsParser.parse(responseText: scheduledEventsText)

        let hotelOffsetSeconds: Int? = {
            guard ref.bookingType == .hotel else { return nil }
            guard let timeZone = TimeZone(identifier: tripDetails.listingTimeZone) else { return nil }
            return timeZone.secondsFromGMT(for: tripDetails.tripStartAt)
        }()

        return ProviderBookingEnrichment(
            deadlines: scheduledParsed.deadlines,
            rateDetails: scheduledParsed.rateDetails,
            passengers: nil,
            hotelOffsetSeconds: hotelOffsetSeconds,
            hotelCheckInMinutes: scheduledParsed.hotelCheckInMinutes,
            hotelCheckOutMinutes: scheduledParsed.hotelCheckOutMinutes,
            status: resolvedStatus
        )
    }
}

private extension AirbnbTravelProvider {
    func extractWebView(from session: any ProviderSession) throws -> WKWebView {
        if let web = (session as? WebViewProviderSession)?.webView {
            return web
        }
        throw RepositoryError.invalidState("Airbnb provider benötigt eine WKWebView-basierten Session.")
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
        tripDetails: AirbnbTripDetails,
        resolvedStatus: BookingStatus?
    ) async throws -> ProviderBookingEnrichment {
        onProgress?("Lade Experience-Details (Airbnb)…")
        let detailsURL = reservationOverviewURL(
            pathPrefix: "/api/v2/activity_reservation_details",
            schedulableType: schedulableType,
            confirmationCode: confirmationCode
        )
        let detailsText = try await webView.airbnbFetchTextAsync(
            url: detailsURL,
            headers: scheduledEventsHeaders(referer: loginURL.absoluteString)
        )
        let parsed = try AirbnbActivityReservationDetailsParser.parse(
            responseText: detailsText,
            referenceDate: tripDetails.tripStartAt
        )

        let guestCount = ([parsed.guestAdults, tripDetails.guestAdults].compactMap { count -> Int? in
            guard let count, count > 0 else { return nil }
            return count
        }).first

        let rateDetails: BookingRateDetails? = {
            guard let guestCount else { return parsed.rateDetails }
            if var details = parsed.rateDetails {
                details.guestCount = guestCount
                return details
            }
            return BookingRateDetails(guestCount: guestCount)
        }()

        return ProviderBookingEnrichment(
            deadlines: parsed.deadlines,
            rateDetails: rateDetails,
            passengers: nil,
            hotelOffsetSeconds: nil,
            hotelCheckInMinutes: nil,
            hotelCheckOutMinutes: nil,
            status: resolvedStatus,
            title: parsed.title,
            locationTo: parsed.locationTo,
            locationToAddress: parsed.locationToAddress
        )
    }

    func scheduledEventsHeaders(referer: String) -> [String: String] {
        [
            "Accept": "application/json",
            "Referer": referer,
        ]
    }

    /// Shared query params for Stay `scheduled_events` and Experience `activity_reservation_details`.
    func reservationOverviewURL(
        pathPrefix: String,
        schedulableType: String,
        confirmationCode: String
    ) -> URL {
        var comps = URLComponents(url: AirbnbAPI.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = "\(pathPrefix)/\(schedulableType)/\(confirmationCode)"
        comps.queryItems = [
            URLQueryItem(name: "locale", value: "de"),
            URLQueryItem(name: "currency", value: "EUR"),
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
}

private extension AirbnbTravelProvider {
    // Intentionally empty: we reuse `ReisenDomain.RepositoryError`.
}

