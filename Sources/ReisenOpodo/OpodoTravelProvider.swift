import Foundation
import WebKit
import ReisenDomain
import ReisenProviders

@MainActor
public final class OpodoTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .opodo }

    public var displayName: String { "Opodo" }

    public var loginURL: URL {
        // HAR: PasswordLogin läuft über Homepage-Stack (Referer www.opodo.de/),
        // nicht über /travel/secure/ (My-Trips/magic_link — hängt in WKWebView bei „Anmelden…“).
        URL(string: "https://www.opodo.de/")!
    }

    public var keychainServerHost: String { "opodo.de" }

    public var onProgress: (@MainActor (String) -> Void)?

    public func fetchCatalog(session: any ProviderSession) async throws -> ProviderCatalog {
        let webView = try webView(from: session)
        try await ensureGraphQLSession(using: webView)
        if let catalog = try await fetchGraphQLCatalog(using: webView) {
            return catalog
        }
        return try await fetchHTMLCatalogFallback(using: webView)
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

    private func fetchGraphQLCatalog(using webView: WKWebView) async throws -> ProviderCatalog? {
        onProgress?("Lade Buchungen (GraphQL getTrips)…")
        do {
            let bookings = try await fetchUpcomingTrips(using: webView)
            guard !bookings.isEmpty else { return nil }
            return ProviderCatalog(bookings: bookings)
        } catch let error as OpodoProviderError {
            if case .sessionNotEstablished = error {
                throw error
            }
            return nil
        } catch let error as AuthenticatedFetchError where AuthenticatedSessionGuard.isUnauthorized(error) {
            throw OpodoProviderError.sessionNotEstablished
        } catch {
            return nil
        }
    }

    private func fetchHTMLCatalogFallback(using webView: WKWebView) async throws -> ProviderCatalog {
        onProgress?("GraphQL-Katalog fehlgeschlagen, lade Buchungen (HTML-Fallback)…")
        let html = try await fetchSecureHTML(using: webView)

        let bookings: [ProviderBookingDraft]
        do {
            bookings = try OpodoActivityListParser().parseBookings(from: html)
        } catch is OpodoActivityListParserError {
            bookings = []
        }
        return ProviderCatalog(bookings: bookings)
    }

    public func enrichBooking(
        session: any ProviderSession,
        ref: ProviderBookingRef
    ) async throws -> ProviderBookingEnrichment {
        let webView = try webView(from: session)
        guard ref.bookingType == .hotel else {
            return try await enrichFlightBooking(webView: webView, externalUrl: ref.externalUrl)
        }

        return try await enrichHotelBooking(webView: webView, externalUrl: ref.externalUrl)
    }

    private func enrichFlightBooking(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ProviderBookingEnrichment {
        guard let token = OpodoGetTripByTokenQuery.tdToken(fromExternalURL: externalUrl) else {
            // Falls kein Token extrahierbar ist, ist ein strukturierter Sync nicht möglich.
            throw OpodoProviderError.catalogNotFound
        }

        onProgress?("Lade Flug-Passagiere & Gepäck…")
        let passengers = try await OpodoFlightPassengersGraphQL.fetchPassengersAndBaggage(
            token: token,
            tripDetailsToken: token,
            using: webView
        )

        // Kompatibilität: bestehende UI/Editor erwartet aktuell `rateDetails.baggageInfoRaw`.
        let baggageInfoRaw = BaggageInfoFormatter.baggageInfoRaw(passengers: passengers)

        return ProviderBookingEnrichment(
            rateDetails: BookingRateDetails(baggageInfoRaw: baggageInfoRaw),
            passengers: passengers,
            status: nil
        )
    }

    private func enrichHotelBooking(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ProviderBookingEnrichment {
        onProgress?("Lade Trip-Storno (GraphQL)…")
        let (graphqlDeadlines, resolvedStatus) = try await fetchGraphQLHotelDeadlinesAndStatus(
            webView: webView,
            externalUrl: externalUrl
        )

        if resolvedStatus == .cancelled {
            return ProviderBookingEnrichment(deadlines: [], status: .cancelled)
        }

        // HTML: Storno-Erkennung + Fallback für Fristen (HAR-SSOT bleibt GraphQL).
        let (htmlDeadlines, htmlResolvedStatus) = try await resolveHtmlDeadlinesIfNeeded(
            graphqlDeadlines: graphqlDeadlines,
            webView: webView,
            externalUrl: externalUrl
        )
        if htmlResolvedStatus == .cancelled {
            return ProviderBookingEnrichment(deadlines: [], status: .cancelled)
        }

        let deadlines = selectHotelDeadlines(
            graphqlDeadlines: graphqlDeadlines,
            htmlDeadlines: htmlDeadlines
        )

        let hotelOffsetSeconds: Int? = deadlines.compactMap(\.hotelOffsetSeconds).first ?? 0
        let pageText = try await loadTripDetailsPageText(in: webView, externalURL: externalUrl)
        let guestHints = StayHintHTMLExtractor.extract(
            from: pageText,
            providerRaw: ProviderID.opodo.rawValue
        )

        return ProviderBookingEnrichment(
            deadlines: deadlines,
            rateDetails: nil,
            guestHints: guestHints.isEmpty ? nil : guestHints,
            hotelOffsetSeconds: hotelOffsetSeconds,
            status: resolvedStatus
        )
    }

    private func fetchGraphQLHotelDeadlinesAndStatus(
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ([CancellationDeadline], BookingStatus?) {
        var graphqlDeadlines: [CancellationDeadline] = []
        var resolvedStatus: BookingStatus?

        if let token = OpodoGetTripByTokenQuery.tdToken(fromExternalURL: externalUrl) {
            do {
                let body = try OpodoGetTripByTokenQuery.requestBody(token: token)
                // HAR: Referer ohne trailing slash.
                let json = try await webView.fetchAuthenticatedText(
                    url: OpodoSessionProbe.graphqlURL,
                    method: "POST",
                    accept: "application/json",
                    referer: "https://www.opodo.de/travel/secure",
                    contentType: "application/json",
                    body: body
                )
                let parsed = try OpodoTripCancellationGraphQLParser().parse(from: json)
                graphqlDeadlines = parsed.deadlines
                resolvedStatus = parsed.status
            } catch {
                onProgress?("GraphQL-Storno fehlgeschlagen, nutze HTML…")
            }
        }

        return (graphqlDeadlines, resolvedStatus)
    }

    private func resolveHtmlDeadlinesIfNeeded(
        graphqlDeadlines: [CancellationDeadline],
        webView: WKWebView,
        externalUrl: String
    ) async throws -> ([CancellationDeadline], BookingStatus?) {
        guard graphqlDeadlines.isEmpty else { return ([], nil) }

        onProgress?("Lade Trip-Details (WebView)…")
        let pageText = try await loadTripDetailsPageText(in: webView, externalURL: externalUrl)
        if OpodoTripCancellationGraphQLParser.looksCancelled(inPageText: pageText) {
            return ([], .cancelled)
        }
        return (OpodoCancellationDeadlineParser().parseDeadlines(from: pageText), nil)
    }

    private func selectHotelDeadlines(
        graphqlDeadlines: [CancellationDeadline],
        htmlDeadlines: [CancellationDeadline]
    ) -> [CancellationDeadline] {
        let latestFree = graphqlDeadlines
            .filter(\.isFreeCancellation)
            .max(by: { $0.deadlineAt < $1.deadlineAt })
        if let latestFree { return [latestFree] }

        let stornoLines = htmlDeadlines.filter(\.isFreeCancellation)
        if !stornoLines.isEmpty { return stornoLines }

        let bestLongDate = htmlDeadlines
            .filter { Self.looksLikeLongDatePolicy($0) }
            .max(by: { $0.deadlineAt < $1.deadlineAt })
        if let bestLongDate { return [bestLongDate] }

        if !graphqlDeadlines.isEmpty { return graphqlDeadlines }
        return htmlDeadlines
    }

    /// Opodo My-Trips ist eine Hash-SPA unter `/travel/secure/`.
    /// Verifiziert: Hash nur auf `www.opodo.de/` setzen landet auf `www.opodo.de/#tripdetails/…`
    /// ohne Secure-Shell — dann fehlt Storno-Text im `innerText`.
    private func loadTripDetailsPageText(in webView: WKWebView, externalURL: String) async throws -> String {
        guard let token = OpodoGetTripByTokenQuery.tdToken(fromExternalURL: externalURL) else {
            if let url = URL(string: externalURL) {
                try await NavigationAwaiter().load(url, in: webView)
            }
            return try await snapshotPageText(in: webView) ?? ""
        }

        let detailURLString = "https://www.opodo.de/travel/secure/#tripdetails/td=\(token)"
        guard let detailURL = URL(string: detailURLString) else {
            throw OpodoProviderError.catalogNotFound
        }

        let alreadyOnDetail = webView.url?.absoluteString == detailURLString
            || (webView.url?.path.contains("/travel/secure") == true
                && webView.url?.fragment == "tripdetails/td=\(token)")
        if !alreadyOnDetail {
            try await NavigationAwaiter().load(detailURL, in: webView)
        }

        var last = ""
        for _ in 0..<24 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            guard let text = try await snapshotPageText(in: webView) else { continue }
            last = text
            if text.localizedCaseInsensitiveContains(OpodoCancellationPolicyLabel.policy)
                || text.localizedCaseInsensitiveContains("cancellation policy") {
                return text
            }
            if text.range(of: #"\d{4}-\d{2}-\d{2}"#, options: .regularExpression) != nil {
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

    private static func looksLikeLongDatePolicy(_ deadline: CancellationDeadline) -> Bool {
        let text = deadline.policyText ?? ""
        return text.range(
            of: #"\d{1,2}\.?\s*[A-Za-zÄÖÜäöü]+\s+\d{4}"#,
            options: .regularExpression
        ) != nil
    }

    private static let secureURL = URL(string: "https://www.opodo.de/travel/secure/")!

    private func fetchSecureHTML(using webView: WKWebView) async throws -> String {
        var lastError: Error?
        for attempt in 1...3 {
            do {
                return try await webView.fetchAuthenticatedHTML(
                    url: Self.secureURL,
                    referer: "https://www.opodo.de/",
                    isLoginHTML: AuthPageHTMLHeuristic.opodoHTMLLooksLikeLogin
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
        guard let webSession = session as? WebViewProviderSession else {
            throw OpodoProviderError.sessionNotEstablished
        }
        return webSession.webView
    }

    private func fetchUpcomingTrips(using webView: WKWebView) async throws -> [ProviderBookingDraft] {
        var all: [ProviderBookingDraft] = []
        for page in 0..<Self.maxPages {
            let body = try OpodoGetTripsQuery.requestBody(
                filter: "UPCOMING",
                maxNumBookingsByPage: Self.pageSize,
                offsetPage: page
            )
            let json = try await webView.fetchAuthenticatedText(
                url: OpodoSessionProbe.graphqlURL,
                method: "POST",
                accept: "application/json",
                referer: "https://www.opodo.de/travel/secure/",
                contentType: "application/json",
                body: body
            )
            let pageBookings = try OpodoTripsGraphQLParser().parseTrips(from: json)
            if pageBookings.isEmpty {
                break
            }
            all.append(contentsOf: pageBookings)
            if pageBookings.count < Self.pageSize {
                break
            }
        }

        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in all {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        return Array(byURL.values).sorted { $0.startAt < $1.startAt }
    }

    /// Session GraphQL from HAR discovery (GetUserAccount). Not a booking catalog.
    private func fetchGraphQLUserAccount(using webView: WKWebView) async throws -> String {
        return try await webView.fetchAuthenticatedText(
            url: OpodoSessionProbe.graphqlURL,
            method: "POST",
            accept: "application/json",
            referer: "https://www.opodo.de/",
            contentType: "application/json",
            body: OpodoSessionProbe.getUserAccountRequestBody()
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
