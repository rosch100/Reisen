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

        onProgress?("Prüfe Opodo-Session (GraphQL)…")
        _ = try? await fetchGraphQLUserAccount(using: webView)

        onProgress?("Lade Buchungen (GraphQL getTrips)…")
        do {
            let bookings = try await fetchUpcomingTrips(using: webView)
            if !bookings.isEmpty {
                return ProviderCatalog(bookings: bookings)
            }
        } catch {
            onProgress?("GraphQL-Katalog fehlgeschlagen, nutze HTML-Fallback…")
        }

        onProgress?("Lade Buchungen (HTML-Fallback)…")
        let html: String
        do {
            html = try await webView.fetchAuthenticatedText(
                url: Self.secureURL,
                accept: "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
                referer: "https://www.opodo.de/"
            )
        } catch {
            onProgress?("Secure-Abruf fehlgeschlagen, nutze WebView-HTML…")
            guard let snapshot = try await webView.evaluateJavaScriptStringAsync("document.documentElement.outerHTML") else {
                throw OpodoProviderError.catalogNotFound
            }
            html = snapshot
        }

        let bookings = try OpodoActivityListParser().parseBookings(from: html)
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

        return ProviderBookingEnrichment(
            deadlines: deadlines,
            rateDetails: nil,
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

        let stornoLines = htmlDeadlines.filter {
            ($0.policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie")
        }
        if !stornoLines.isEmpty { return stornoLines }

        let bestLongDate = htmlDeadlines
            .filter { Self.looksLikeGermanLongPolicy($0) }
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
            if text.localizedCaseInsensitiveContains("Stornierungsrichtlinie") {
                return text
            }
            // Hotel-Policy oft als „Bis 1. August 2026 (Bis 22:00)“ ohne Label im innerText-Ausschnitt.
            if text.range(of: #"Bis\s+\d{1,2}\.?\s*[A-Za-zÄÖÜäöü]+\s+\d{4}"#, options: [.regularExpression, .caseInsensitive]) != nil {
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

    private static func looksLikeGermanLongPolicy(_ deadline: CancellationDeadline) -> Bool {
        let text = deadline.policyText ?? ""
        return text.range(
            of: #"\d{1,2}\.?\s*[A-Za-zÄÖÜäöü]+\s+\d{4}"#,
            options: .regularExpression
        ) != nil
    }

    private static let secureURL = URL(string: "https://www.opodo.de/travel/secure/")!
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
