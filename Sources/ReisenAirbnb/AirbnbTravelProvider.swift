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

        onProgress?("Lade Reservation-Overview (Airbnb)…")
        let scheduledEventsURL = scheduledEventsURL(
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

        let resolvedStatus: BookingStatus? = {
            guard let reservationStatus = tripDetails.reservationStatus else { return nil }
            let haystack = reservationStatus.lowercased()
            if haystack.contains("cancel") { return .cancelled }
            return .confirmed
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

    func scheduledEventsHeaders(referer: String) -> [String: String] {
        [
            "Accept": "application/json",
            "Referer": referer,
        ]
    }

    func scheduledEventsURL(schedulableType: String, confirmationCode: String) -> URL {
        var comps = URLComponents(url: AirbnbAPI.baseURL, resolvingAgainstBaseURL: false)!
        comps.path = "/api/v2/scheduled_events/\(schedulableType)/\(confirmationCode)"
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

