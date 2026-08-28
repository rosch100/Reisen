import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class OpodoTravelProvider: TravelProvider, TravelProviderLoginConfiguration, TravelProviderProgressReporting {
    public init() {}

    public var id: ProviderID { .opodo }

    public var displayName: String { "Opodo" }

    public var loginURL: URL {
        // HAR: PasswordLogin läuft über Homepage-Stack (Referer www.opodo.de/),
        // nicht über /travel/secure/ (My-Trips/magic_link — hängt in WKWebView bei „Anmelden…“).
        OpodoWeb.homepageURL
    }

    public var keychainServerHost: String { "opodo.de" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)
        try await ensureGraphQLSession(using: webView)
        let graphQL = try await fetchUpcomingTrips(using: webView)
        if graphQL.needsHTMLFallback {
            return graphQL.resolved(htmlFallback: try await fetchHTMLCatalogFallback(using: webView))
        }
        return graphQL.resolved()
    }

    private func ensureGraphQLSession(using webView: WKWebView) async throws {
        onProgress?("Prüfe Opodo-Session (GraphQL)…")
        do {
            let accountJSON = try await fetchGraphQLUserAccount(using: webView)
            if let loggedIn = OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: accountJSON), !loggedIn {
                throw OpodoProviderError.sessionNotEstablished
            }
        } catch let error as OpodoProviderError {
            throw error
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw OpodoProviderError.sessionNotEstablished
        } catch {
            // Probe fehlgeschlagen: getTrips bleibt maßgeblich.
        }
    }

    private func fetchHTMLCatalogFallback(using webView: WKWebView) async throws -> [ProviderBookingDraft] {
        onProgress?("GraphQL-Katalog leer, lade Buchungen (HTML-Fallback)…")
        let html = try await fetchSecureHTML(using: webView)
        return try OpodoActivityListParser().parseBookings(from: html)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        switch ref.bookingType {
        case .hotel:
            return try await enrichHotelBooking(webView: webView, externalUrl: ref.externalUrl)
        case .flight:
            return try await enrichFlightBooking(webView: webView, externalUrl: ref.externalUrl)
        case .ferry, .train, .activity, .carRental, .other:
            throw OpodoProviderError.catalogNotFound
        }
    }

    private func enrichFlightBooking(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ProviderBookingEnrichment {
        guard let token = OpodoWeb.tdToken(fromExternalURL: externalUrl) else {
            // Falls kein Token extrahierbar ist, ist ein strukturierter Sync nicht möglich.
            throw OpodoProviderError.catalogNotFound
        }

        onProgress?("Lade Flug-Passagiere & Gepäck…")
        let passengers = try await OpodoFlightPassengersGraphQL.fetchPassengersAndBaggage(
            token: token,
            using: webView
        )

        // Kompatibilität: bestehende UI/Editor erwartet aktuell `rateDetails.baggageInfoRaw`.
        let baggageInfoRaw = BaggageInfoFormatter.baggageInfoRaw(passengers: passengers)

        return DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: .flight,
                rateDetails: BookingRateDetails(baggageInfoRaw: baggageInfoRaw),
                passengers: passengers
            )
        )
    }

    private func enrichHotelBooking(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ProviderBookingEnrichment {
        onProgress?("Lade Trip-Storno (GraphQL)…")
        let (graphqlDeadlines, statusRaw) = try await fetchGraphQLHotelDeadlinesAndStatus(
            webView: webView,
            externalUrl: externalUrl
        )

        if !CatalogListing.shouldFetchDetails(statusRaw) {
            return OpodoHotelGraphQLEnrichment.make(
                statusRaw: statusRaw,
                deadlines: graphqlDeadlines,
                guestHints: []
            )
        }

        let deadlines = graphqlDeadlines.preferringLatestFree
        let pageText = try await loadTripDetailsPageText(in: webView, externalURL: externalUrl)
        let guestHints = StayHintHTMLExtractor.extract(
            from: pageText,
            providerRaw: ProviderID.opodo.rawValue
        )

        return OpodoHotelGraphQLEnrichment.make(
            statusRaw: statusRaw,
            deadlines: deadlines,
            guestHints: guestHints
        )
    }

    private func fetchGraphQLHotelDeadlinesAndStatus(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ([CancellationDeadline], String?) {
        var graphqlDeadlines: [CancellationDeadline] = []
        var statusRaw: String?

        if let token = OpodoWeb.tdToken(fromExternalURL: externalUrl) {
            do {
                let body = try OpodoGetTripByTokenQuery.requestBody(token: token)
                let json = try await postFrontendGraphQL(
                    using: webView,
                    body: body,
                    referer: OpodoWeb.secureAreaRefererWithoutTrailingSlash
                )
                let parsed = try OpodoTripCancellationGraphQLParser().parse(from: json)
                graphqlDeadlines = parsed.deadlines
                statusRaw = parsed.statusRaw
            } catch let error as OpodoProviderError {
                throw error
            } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
                throw OpodoProviderError.sessionNotEstablished
            } catch {
                // GraphQL SSOT für Storno; Guest-Hints werden separat aus Trip-Details geladen.
                return ([], nil)
            }
        }

        return (graphqlDeadlines, statusRaw)
    }

    /// Opodo My-Trips ist eine Hash-SPA unter `/travel/secure/`.
    /// Verifiziert: Hash nur auf `www.opodo.de/` setzen landet auf `www.opodo.de/#tripdetails/…`
    /// ohne Secure-Shell — dann fehlt Storno-Text im `innerText`.
    private func loadTripDetailsPageText(in webView: WKWebView, externalURL: String) async throws -> String {
        guard let token = OpodoWeb.tdToken(fromExternalURL: externalURL) else {
            if let url = URL(string: externalURL) {
                try await NavigationAwaiter().load(url, in: webView)
            }
            return try await snapshotPageText(in: webView) ?? ""
        }

        let detailURLString = OpodoWeb.tripDetailsURL(token: token)
        guard let detailURL = URL(string: detailURLString) else {
            throw OpodoProviderError.catalogNotFound
        }

        let alreadyOnDetail = webView.url?.absoluteString == detailURLString
            || (webView.url?.path.hasPrefix(OpodoWeb.secureAreaPathPrefix) == true
                && webView.url?.fragment == detailURL.fragment)
        if !alreadyOnDetail {
            try await NavigationAwaiter().load(detailURL, in: webView)
        }

        var last = ""
        for _ in 0..<24 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let text = try await snapshotPageText(in: webView) else { continue }
            last = text
            if text.count >= 120
                || text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
                return text
            }
        }
        return last
    }

    private func snapshotPageText(in webView: WKWebView) async throws -> String? {
        let js = """
        (function() {
          return (document.body && document.body.innerText) ? document.body.innerText : '';
        })()
        """
        return try await webView.evaluateJavaScriptStringAsync(js)
    }

    private func fetchSecureHTML(using webView: WKWebView) async throws -> String {
        var lastError: Error?
        for attempt in 1...3 {
            do {
                return try await webView.fetchAuthenticatedHTML(
                    url: OpodoWeb.secureAreaURL,
                    referer: loginURL.absoluteString,
                    isLoginHTML: AuthPageHTMLHeuristic.opodoLooksLikeLoginHTML
                )
            } catch AuthenticatedSessionError.notEstablished {
                throw OpodoProviderError.sessionNotEstablished
            } catch let error as OpodoProviderError {
                throw error
            } catch {
                lastError = error
                if attempt < 3 {
                    try await Task.sleep(nanoseconds: UInt64(attempt) * 400_000_000)
                }
            }
        }
        throw lastError ?? OpodoProviderError.catalogNotFound
    }

    /// HAR nutzt 5; kleiner Page-Size hält Pagination korrekt, wenn das Backend cappt.
    private static let pageSize = 5
    private static let maxPages = 20

    private func webView(from session: any ProviderSession) throws -> WKWebView {
        try ProviderWebView.webView(from: session, orThrow: OpodoProviderError.sessionNotEstablished)
    }

    private func fetchUpcomingTrips(using webView: WKWebView) async throws -> OpodoGraphQLCatalog {
        onProgress?("Lade Buchungen (GraphQL getTrips)…")
        do {
            return try await loadUpcomingTripPages(using: webView)
        } catch OpodoTripsGraphQLParserError.notLoggedIn {
            throw OpodoProviderError.sessionNotEstablished
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw OpodoProviderError.sessionNotEstablished
        }
    }

    private func loadUpcomingTripPages(using webView: WKWebView) async throws -> OpodoGraphQLCatalog {
        var all: [ProviderBookingDraft] = []
        var rawTripCount = 0
        for page in 0..<Self.maxPages {
            let body = try OpodoGetTripsQuery.requestBody(
                filter: "UPCOMING",
                maxNumBookingsByPage: Self.pageSize,
                offsetPage: page
            )
            let json = try await postFrontendGraphQL(
                using: webView,
                body: body,
                referer: OpodoWeb.secureAreaURLString
            )
            let pageResult = try OpodoTripsGraphQLParser().parseTripPage(from: json)
            rawTripCount += pageResult.rawTripCount
            guard pageResult.rawTripCount > 0 else { break }
            all.append(contentsOf: pageResult.bookings)
            if pageResult.rawTripCount < Self.pageSize {
                break
            }
        }

        return OpodoGraphQLCatalog(
            bookings: all,
            rawTripCount: rawTripCount
        )
    }

    /// Session GraphQL from HAR discovery (GetUserAccount). Not a booking catalog.
    private func fetchGraphQLUserAccount(using webView: WKWebView) async throws -> String {
        try await postFrontendGraphQL(
            using: webView,
            body: OpodoSessionProbe.getUserAccountRequestBody(),
            referer: loginURL.absoluteString
        )
    }

    private func postFrontendGraphQL(
        using webView: WKWebView,
        body: Data,
        referer: String
    ) async throws -> String {
        try await webView.fetchAuthenticatedText(
            url: OpodoSessionProbe.graphqlURL,
            method: "POST",
            accept: "application/json",
            referer: referer,
            contentType: "application/json",
            body: body
        )
    }
}

enum OpodoHotelGraphQLEnrichment {
    static func make(
        statusRaw: String?,
        deadlines: [CancellationDeadline],
        guestHints: [BookingGuestHint]
    ) -> ProviderBookingEnrichment {
        DraftAssembler.enrichment(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: .hotel,
                statusRaw: statusRaw,
                deadlines: deadlines,
                guestHints: guestHints
            )
        )
    }
}

public enum OpodoProviderError: LocalizedError, Sendable {
    case sessionNotEstablished
    case catalogNotFound

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Opodo Session. Bitte zunächst anmelden."
        case .catalogNotFound:
            return "Opodo-Katalog konnte nicht geladen werden."
        }
    }
}
