import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

/// WebView-Interface für Booking.com-spezifische Fetch-/JS-Operationen.
/// Ziel: Hotspots in `BookingComTravelProvider` ohne echtes `WKWebView` testbar machen.
internal protocol BookingComWebView: NavigationWebView {
    func evaluateJavaScriptStringAsync(_ javaScript: String) async throws -> String?
    func fetchInPageText(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> String

    func fetchAuthenticatedText(
        url: URL,
        method: String,
        accept: String,
        referer: String?,
        contentType: String?,
        body: Data?,
        headers: [String: String]
    ) async throws -> String
}

extension WKWebView: BookingComWebView {}

/// Session-Interface für `BookingComWebView`.
///
/// Main-Actor-isoliert, damit die `WebViewProviderSession`-Conformance zu `BookingComWebViewSession`
/// keine `[ConformanceIsolation]`-Fehler in Swift 6.2+ auslöst.
@MainActor
internal protocol BookingComWebViewSession: ProviderSession {
    var bookingComWebView: BookingComWebView { get }
}

extension WebViewProviderSession: BookingComWebViewSession {
    var bookingComWebView: BookingComWebView { webView }
}

@MainActor
public final class BookingComTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .booking }

    public var displayName: String { "Booking.com" }

    /// My Trips is the session-bound catalog surface (no public consumer Orders API).
    public var loginURL: URL {
        URL(string: "https://secure.booking.com/mytrips.de.html")!
    }

    public var keychainServerHost: String { "booking.com" }

    public var onProgress: (@MainActor (String) -> Void)?

    private enum CatalogFallbackResult {
        case bookings([ProviderBookingDraft])
        case none
    }

    private enum GraphQLAttemptResult {
        case bookings([ProviderBookingDraft])
        case empty
        case error(Error)
    }

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)

        onProgress?("Lade My Trips (session-gebunden)…")
        let myTripsHTML = try await loadMyTripsHTML(using: webView)
        let htmlTripIDs = BookingComParsing.tripIDsFromMyTripsHTML(myTripsHTML)

        onProgress?("Lade Buchungen (GraphQL)…")
        var lastGraphQLError: Error?
        switch await attemptGraphQLCatalog(
            using: webView,
            myTripsHTML: myTripsHTML,
            preferredTripIDs: htmlTripIDs
        ) {
        case .bookings(let bookings):
            return ProviderCatalog(bookings: bookings)
        case .empty:
            break
        case .error(let error):
            lastGraphQLError = error
            onProgress?("GraphQL-Katalog fehlgeschlagen, nutze HTML-Fallback…")
        }

        let fallback = try fetchCatalogFallbackHTML(htmlTripIDs: htmlTripIDs, myTripsHTML: myTripsHTML)
        switch fallback {
        case .bookings(let bookings):
            return ProviderCatalog(bookings: bookings)
        case .none:
            break
        }

        if let lastGraphQLError {
            throw lastGraphQLError
        }
        throw BookingComProviderError.catalogNotFound
    }

    private func attemptGraphQLCatalog(
        using webView: BookingComWebView,
        myTripsHTML: String,
        preferredTripIDs: [String]
    ) async -> GraphQLAttemptResult {
        do {
            let bookings = try await fetchGraphQLCatalog(
                using: webView,
                myTripsHTML: myTripsHTML,
                preferredTripIDs: preferredTripIDs
            )
            return bookings.isEmpty ? .empty : .bookings(bookings)
        } catch {
            return .error(error)
        }
    }

    private func fetchCatalogFallbackHTML(
        htmlTripIDs: [String],
        myTripsHTML: String
    ) throws -> CatalogFallbackResult {
        // Marketing-Copy ist kein Empty-Signal (HAR). Ohne trip_id= und ohne Card-HTML → leer.
        if htmlTripIDs.isEmpty {
            return try fetchCatalogFallbackHTMLWhenTripIDsEmpty(myTripsHTML: myTripsHTML)
        }

        return fetchCatalogFallbackHTMLWhenTripIDsNotEmpty(myTripsHTML: myTripsHTML)
    }

    private func fetchCatalogFallbackHTMLWhenTripIDsEmpty(
        myTripsHTML: String
    ) throws -> CatalogFallbackResult {
        do {
            let bookings = try BookingComActivityListParser().parseBookings(from: myTripsHTML)
            return .bookings(bookings)
        } catch is BookingComActivityListParserError {
            return .bookings([])
        }
    }

    private func fetchCatalogFallbackHTMLWhenTripIDsNotEmpty(
        myTripsHTML: String
    ) -> CatalogFallbackResult {
        do {
            let bookings = try BookingComActivityListParser().parseBookings(from: myTripsHTML)
            guard !bookings.isEmpty else { return .none }
            return .bookings(bookings)
        } catch {
            // trip_id vorhanden, Card-HTML nicht parsebar
            return .none
        }
    }

    /// Trip-XP GraphQL: GetTrips → SingleTimeline pro Trip → Dedup.
    private func fetchGraphQLCatalog(
        using webView: BookingComWebView,
        myTripsHTML: String,
        preferredTripIDs: [String]
    ) async throws -> [ProviderBookingDraft] {
        let tokens = try BookingComSessionTokens.extract(from: myTripsHTML)
        let tripIDs = await resolveTripIDs(preferredTripIDs: preferredTripIDs, using: webView, tokens: tokens)
        guard !tripIDs.isEmpty else { return [] }

        let result = await fetchTimelineCatalog(
            using: webView,
            tokens: tokens,
            tripIDs: tripIDs
        )

        if !result.bookings.isEmpty {
            return BookingComParsing.dedupeByExternalURL(result.bookings)
        }
        if result.timelineFailures == tripIDs.count, let lastTimelineError = result.lastTimelineError {
            throw lastTimelineError
        }
        throw BookingComProviderError.catalogNotFound
    }

    private func resolveTripIDs(
        preferredTripIDs: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async -> [String] {
        var tripIDs = await fetchAllTripIDs(using: webView, tokens: tokens)
        if tripIDs.isEmpty {
            return preferredTripIDs
        }

        // SSR-Upcoming zuerst, dann Rest aus GetTrips (ohne Duplikate).
        var ordered = preferredTripIDs
        var seen = Set(preferredTripIDs)
        for id in tripIDs where !seen.contains(id) {
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }

    private func fetchTimelineCatalog(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        tripIDs: [String]
    ) async -> (bookings: [ProviderBookingDraft], timelineFailures: Int, lastTimelineError: Error?) {
        var bookings: [ProviderBookingDraft] = []
        var timelineFailures = 0
        var lastTimelineError: Error?

        for (index, tripID) in tripIDs.enumerated() {
            onProgress?("Lade Trip-Details \(index + 1)/\(tripIDs.count)…")
            do {
                let timelineJSON = try await fetchTimelineGraphQL(
                    using: webView,
                    tokens: tokens,
                    tripID: tripID
                )
                let drafts = try BookingComTripsGraphQLParser().parseTimeline(from: timelineJSON)
                bookings.append(contentsOf: drafts)
            } catch {
                lastTimelineError = error
                timelineFailures += 1
            }
        }

        return (bookings, timelineFailures, lastTimelineError)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard let url = URL(string: ref.externalUrl) else {
            throw BookingComProviderError.catalogNotFound
        }

        if ref.bookingType == .flight {
            return try await enrichFlight(using: webView, confirmationURL: url)
        }

        onProgress?("Lade Buchungsdetails…")
        guard let confirmationURL = BookingComParsing.normalizedHotelConfirmationURL(ref.externalUrl)
            .flatMap(URL.init(string:)) else {
            return ProviderBookingEnrichment()
        }
        let html = try await loadHotelConfirmationHTML(using: webView, url: confirmationURL)
        let deadlines = BookingComCancellationDeadlineParser().parseDeadlines(
            from: html,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
        let rateDetails = BookingComHotelConfirmationParser().parseRateDetails(from: html)
        return ProviderBookingEnrichment(
            deadlines: deadlines,
            rateDetails: rateDetails,
            hotelOffsetSeconds: ref.hotelOffsetSeconds
        )
    }

    /// HAR: Fee-Schedule nur auf `confirmation.html` (nicht locale `confirmation.de.html`); Session/WAF via WebView.
    private func loadHotelConfirmationHTML(using webView: BookingComWebView, url: URL) async throws -> String {
        do {
            let text = try await webView.fetchInPageText(
                url: url,
                method: "GET",
                headers: [
                    "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                    "Referer": Self.myTripsURL.absoluteString,
                ],
                body: nil
            )
            if Self.looksLikeHotelConfirmation(text) {
                return text
            }
        } catch {
            // Navigation-Fallback unten.
        }

        try await NavigationAwaiter().load(url, in: webView)
        try? await Task.sleep(nanoseconds: 600_000_000)
        if let snapshot = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML"),
           Self.looksLikeHotelConfirmation(snapshot) {
            return snapshot
        }

        return try await webView.fetchAuthenticatedText(
            url: url,
            method: "GET",
            accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
            referer: Self.myTripsURL.absoluteString,
            contentType: nil,
            body: nil,
            headers: [:]
        )
    }

    private static func looksLikeHotelConfirmation(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("e2e-cancellation-breakdown")
            || lower.contains("e2e-conf-cancellation-cost")
            || lower.contains("stornierungsgebühren")
            || lower.contains("conf-free-cancellation")
            || lower.contains("cancellation_fee")
    }

    private static let myTripsURL = URL(string: "https://secure.booking.com/mytrips.de.html")!
    private static let graphqlURL = URL(string: "https://secure.booking.com/dml/graphql")!
    private static let apolloClientName = "b-trips-frontend-trip-xp-mfe"

    private static let getTripsQuery = """
    query GetTripsQuery($input: GetTripsInput!) {
      tripsQueries {
        getTrips(input: $input) {
          __typename
          ... on GetTripsList {
            trips {
              id
              title
              startDateTime
              endDateTime
              canceled
              numberOfReservations
              __typename
            }
            nextPageData {
              paginationToken
              __typename
            }
            __typename
          }
          ... on TripsListError {
            statusCode
            response
            __typename
          }
        }
        __typename
      }
    }
    """

    /// HAR-shaped: gemeinsame Reservation-Felder außerhalb der Inline-Fragments.
    private static let singleTimelineQuery = """
    query SingleTimelineQuery($input: SingleTripTimelineInput!) {
      singleTripTimelineQueries {
        singleTripTimeline(input: $input) {
          ... on TripTimeline {
            trip {
              id
              title
              startDateTime
              endDateTime
              canceled
              __typename
            }
            timelineGroups {
              tripItems {
                __typename
                ... on ReservationTripItem {
                  reservation {
                    __typename
                    bookingUrl
                    startDateTime
                    endDateTime
                    verticalType
                    reservationStatus
                    price { amount currency __typename }
                    identifiers {
                      publicId
                      publicFacingIdentifier
                      ... on AccommodationReservationIdentifiers {
                        hotelReservationId
                        __typename
                      }
                      __typename
                    }
                    ... on AccommodationReservation {
                      reservationDetailsURL
                      numOfRooms
                      authKey
                      checkIn { start end __typename }
                      checkOut { start end __typename }
                      policy { name type message __typename }
                      propertyData {
                        ... on ReservationPropertyData {
                          name
                          location {
                            city
                            ... on AccommodationLocation {
                              address
                              __typename
                            }
                            __typename
                          }
                          __typename
                        }
                        __typename
                      }
                    }
                    ... on FlightReservation {
                      passengerCount
                      flightComponents {
                        parts {
                          flightNumber
                          startDateTime
                          endDateTime
                          startLocation {
                            iata
                            location { city __typename }
                            __typename
                          }
                          endLocation {
                            iata
                            location { city __typename }
                            __typename
                          }
                          marketingCarrier { code __typename }
                          __typename
                        }
                        __typename
                      }
                    }
                  }
                }
              }
              __typename
            }
            __typename
          }
        }
        __typename
      }
    }
    """

    private func webView(from session: any ProviderSession) throws -> BookingComWebView {
        guard let webSession = session as? BookingComWebViewSession else {
            throw BookingComProviderError.sessionNotEstablished
        }
        return webSession.bookingComWebView
    }

    private func loadMyTripsHTML(using webView: BookingComWebView) async throws -> String {
        // GraphQL im Browser-Kontext braucht die My-Trips-Seite (Referer/Capla/CSRF).
        let onMyTrips = (webView.url?.host?.contains("booking.com") == true)
            && (webView.url?.path.localizedCaseInsensitiveContains("mytrips") == true)
        if !onMyTrips {
            try await NavigationAwaiter().load(Self.myTripsURL, in: webView)
        }

        if let html = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML"),
           html.contains("csrfToken") || html.contains("trip_id=") {
            return html
        }

        do {
            return try await webView.fetchAuthenticatedText(
                url: Self.myTripsURL,
                method: "GET",
                accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                referer: "https://secure.booking.com/",
                contentType: nil,
                body: nil,
                headers: [:]
            )
        } catch {
            throw BookingComProviderError.catalogNotFound
        }
    }

    /// Nur aktuelle/kommende Reisen (HAR SSR). PAST bläht den Katalog auf und ist für Sync irrelevant.
    private static let tripListStageGroups: [[String]] = [
        ["CURRENT", "UPCOMING"],
    ]

    private func fetchAllTripIDs(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens
    ) async -> [String] {
        var orderedIDs: [String] = []
        var seen = Set<String>()
        let parser = BookingComTripsGraphQLParser()

        for stages in Self.tripListStageGroups {
            let stageIDs = await fetchTripIDsForStageGroup(
                stages: stages,
                using: webView,
                tokens: tokens,
                parser: parser,
                seen: &seen
            )
            orderedIDs.append(contentsOf: stageIDs)
        }

        return orderedIDs
    }

    private func fetchTripIDsForStageGroup(
        stages: [String],
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        parser: BookingComTripsGraphQLParser,
        seen: inout Set<String>
    ) async -> [String] {
        var orderedIDs: [String] = []
        do {
            var paginationToken: String? = nil
            repeat {
                let page = try await fetchTripIDsPage(
                    using: webView,
                    tokens: tokens,
                    stages: stages,
                    paginationToken: paginationToken
                )

                for id in page.tripIDs where !seen.contains(id) {
                    seen.insert(id)
                    orderedIDs.append(id)
                }

                paginationToken = page.nextPaginationToken
            } while paginationToken != nil
        } catch {
            // Stage-Gruppe fehlgeschlagen → nächste / SSR-Fallback.
        }

        return orderedIDs
    }

    private func fetchTripIDsPage(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        stages: [String],
        paginationToken: String?
    ) async throws -> (tripIDs: [String], nextPaginationToken: String?) {
        let json = try await fetchGetTripsGraphQL(
            using: webView,
            tokens: tokens,
            stages: stages,
            paginationToken: paginationToken
        )

        let parser = BookingComTripsGraphQLParser()
        let tripIDs = try parser.parseTripIDs(fromGetTripsJSON: json)
        let nextPaginationToken = try parser.parsePaginationToken(fromGetTripsJSON: json)
        return (tripIDs, nextPaginationToken)
    }

    private func fetchGetTripsGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        stages: [String],
        paginationToken: String?
    ) async throws -> String {
        // HAR: rowsPerPage 10, headerSize 672×378 für Trip-Karten.
        var pagination: [String: Any] = ["rowsPerPage": 10]
        if let paginationToken {
            pagination["paginationToken"] = paginationToken
        } else {
            pagination["paginationToken"] = NSNull()
        }
        let variables: [String: Any] = [
            "input": [
                "stages": stages,
                "pagination": pagination,
                "headerSize": [["width": 672, "height": 378]],
            ],
        ]
        return try await postGraphQL(
            using: webView,
            tokens: tokens,
            operationName: "GetTripsQuery",
            query: Self.getTripsQuery,
            variables: variables
        )
    }

    private func fetchTimelineGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        tripID: String
    ) async throws -> String {
        // HAR 2026-07-20: volle Connector-/Experience-Listen + Thumbnail-Größe.
        let variables: [String: Any] = [
            "input": [
                "tripId": tripID,
                "thumbnailSize": ["width": 2192, "height": 548],
                "selectConnectorChannels": ["MY_TRIPS_TIMELINE"],
                "supportedConnectors": Self.timelineSupportedConnectors,
                "supportedExperiences": [
                    "ACCOMMODATION_ARRIVAL",
                    "ACCOMMODATION_INSTAY",
                    "ACCOMMODATION_PRETRIPS",
                    "BHOME_ARRIVAL",
                    "POST_TRIP",
                    "TAXI_ARRIVAL",
                ],
            ],
        ]
        return try await postGraphQL(
            using: webView,
            tokens: tokens,
            operationName: "SingleTimelineQuery",
            query: Self.singleTimelineQuery,
            variables: variables
        )
    }

    private static let timelineSupportedConnectors: [String] = [
        "ACCOMMODATION_POB", "ADD_REVIEW", "APP_MANAGE_RESERVATION",
        "BASIC_TRIP", "CANCEL_BOOKING", "CONTACT_HELP_CENTER",
        "FLIGHT_CANCELLATION_INFO", "FLIGHT_DELAY_INFO", "FLIGHT_ONLINE_CHECK_IN",
        "FREE_CANCELLATION_REMINDER", "GET_DIRECTION", "HELP_CENTER",
        "MESSAGE_PROPERTY", "VIEW_RESERVATION", "MENU_ITEM_VIEW_RESERVATION",
        "MENU_ITEM_CANCEL_RESERVATION", "MENU_ITEM_VIEW_CANCEL_POLICY",
    ]

    private func postGraphQL(
        using webView: BookingComWebView,
        tokens: BookingComSessionTokens,
        operationName: String,
        query: String,
        variables: [String: Any]
    ) async throws -> String {
        let bodyObject: [String: Any] = [
            "operationName": operationName,
            "variables": variables,
            "query": query,
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyObject)
        let headers: [String: String] = [
            "Accept": "*/*",
            "Content-Type": "application/json",
            "Origin": "https://secure.booking.com",
            "x-booking-csrf-token": tokens.csrfToken,
            "apollographql-client-name": Self.apolloClientName,
            "apollographql-client-version": tokens.apolloClientVersion,
            "x-booking-site-type-id": "1",
            "x-booking-topic": "capla_browser_b-trips-frontend-trip-xp-mfe",
            "x-booking-context-action": "mytrips",
            "x-booking-context-action-name": "mytrips",
        ]

        // Primär: In-Page-fetch (HAR/WAF/Cookies im Browser-Kontext).
        do {
            return try await webView.fetchInPageText(
                url: Self.graphqlURL,
                method: "POST",
                headers: headers,
                body: body
            )
        } catch {
            return try await webView.fetchAuthenticatedText(
                url: Self.graphqlURL,
                method: "POST",
                accept: "*/*",
                referer: Self.myTripsURL.absoluteString,
                contentType: "application/json",
                body: body,
                headers: headers
            )
        }
    }

    private func enrichFlight(
        using webView: BookingComWebView,
        confirmationURL: URL
    ) async throws -> ProviderBookingEnrichment {
        guard let orderToken = Self.flightOrderToken(from: confirmationURL) else {
            return ProviderBookingEnrichment()
        }

        onProgress?("Lade Flug-Stornooptionen…")

        guard let orderURL = flightOrderURL(orderToken: orderToken) else {
            return ProviderBookingEnrichment()
        }

        guard let json = try await flightOrderJSON(
            using: webView,
            orderURL: orderURL,
            confirmationURL: confirmationURL
        ) else {
            return ProviderBookingEnrichment()
        }

        guard let parsed = parseFlightOrder(json: json) else {
            return ProviderBookingEnrichment()
        }

        return ProviderBookingEnrichment(
            deadlines: parsed.deadlines,
            rateDetails: parsed.rateDetails,
            passengers: parsed.passengers.isEmpty ? nil : parsed.passengers,
            flightDepartureOffsetSeconds: parsed.flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: parsed.flightArrivalOffsetSeconds
        )
    }

    private func flightOrderURL(orderToken: String) -> URL? {
        var components = URLComponents(
            string: "https://flights.booking.com/api/order/\(orderToken)"
        )!
        components.queryItems = [
            URLQueryItem(name: "pb", value: "1"),
            URLQueryItem(name: "includeAvailableExtras", value: "1"),
            URLQueryItem(name: "cancellationOptionsType", value: "1"),
        ]
        return components.url
    }

    private func flightOrderJSON(
        using webView: BookingComWebView,
        orderURL: URL,
        confirmationURL: URL
    ) async throws -> String? {
        do {
            return try await webView.fetchAuthenticatedText(
                url: orderURL,
                method: "GET",
                accept: "application/json, text/plain, */*",
                referer: confirmationURL.absoluteString,
                contentType: nil,
                body: nil,
                headers: [
                    "Origin": "https://flights.booking.com",
                ]
            )
        } catch {
            return nil
        }
    }

    private func parseFlightOrder(json: String) -> BookingComFlightOrderParseResult? {
        do {
            return try BookingComFlightOrderParser().parse(from: json)
        } catch {
            return nil
        }
    }

    /// Confirmation URL path: `/confirmation/{orderToken}`
    nonisolated public static func flightOrderToken(from url: URL) -> String? {
        let parts = url.path.split(separator: "/").map(String.init)
        guard let idx = parts.firstIndex(of: "confirmation"),
              parts.index(after: idx) < parts.endIndex else {
            return nil
        }
        let token = parts[parts.index(after: idx)]
        return token.isEmpty ? nil : token
    }

    /// My Trips SSR exposes upcoming trips as `trip_id=` even when empty-state copy is present.
    nonisolated public static func tripIDsFromMyTripsHTML(_ html: String) -> [String] {
        BookingComParsing.tripIDsFromMyTripsHTML(html)
    }

}

public enum BookingComProviderError: LocalizedError, Sendable {
    case sessionNotEstablished
    case catalogNotFound
    case sessionTokensMissing

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Booking.com Session. Bitte zunächst anmelden."
        case .catalogNotFound:
            return "Booking.com-Katalog konnte nicht geladen werden."
        case .sessionTokensMissing:
            return "Booking.com Session-Token fehlt. Bitte erneut anmelden und synchronisieren."
        }
    }
}
