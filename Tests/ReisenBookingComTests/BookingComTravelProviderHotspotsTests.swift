import Testing
import Foundation
import WebKit
import ReisenDomain
import ReisenProviders
@testable import ReisenBookingCom

enum FakeBookingComError: Error, Equatable {
    case graphqlFailed
    case unexpectedCall(String)
}

final class FakeBookingComWebView: BookingComWebView {
    // NavigationWebView
    var url: URL?
    var isLoading: Bool = false

    // Behavior knobs
    var outerHTML: String?
    var hotelConfirmationHTML: String?
    var inPageThrowsForGraphQL: Bool = false
    var authenticatedThrowsForGraphQL: Bool = false
    var flightOrderJSON: String?

    // Track whether navigation was requested (for fallback tests).
    private(set) var loadRequests: [URLRequest] = []

    init(url: URL?) {
        self.url = url
    }

    func load(_ request: URLRequest) -> WKNavigation? {
        loadRequests.append(request)
        // Keep it simple: don't mutate `url`/`isLoading` unless the test needs it.
        return nil
    }

    func evaluateJavaScriptStringAsync(_ javaScript: String) async throws -> String? {
        if javaScript.contains("outerHTML") {
            return outerHTML
        }
        return nil
    }

    func fetchInPageText(
        url: URL,
        method: String,
        headers: [String: String],
        body: Data?
    ) async throws -> String {
        guard method.uppercased() == "GET" || method.uppercased() == "POST" else {
            throw FakeBookingComError.unexpectedCall("fetchInPageText method \(method)")
        }

        let urlString = url.absoluteString
        if urlString == "https://secure.booking.com/dml/graphql" {
            if inPageThrowsForGraphQL {
                throw FakeBookingComError.graphqlFailed
            }
            guard let body else {
                throw FakeBookingComError.unexpectedCall("fetchInPageText missing body")
            }
            let obj = try JSONSerialization.jsonObject(with: body) as? [String: Any]
            let operationName = obj?["operationName"] as? String
            if operationName == "GetTripsQuery" {
                return try fixtureJSON("get_trips_compact.json")
            }
            if operationName == "SingleTimelineQuery" {
                return try fixtureJSON("single_timeline_kuta_muenchen.json")
            }
            throw FakeBookingComError.unexpectedCall("fetchInPageText unknown operation \(operationName ?? "nil")")
        }

        // Hotel confirmation in-page fetch: return configured HTML or throw.
        if urlString.contains("confirmation.html") || urlString.contains("confirmation.de.html") {
            if let html = hotelConfirmationHTML {
                return html
            }
            throw FakeBookingComError.unexpectedCall("hotelConfirmationHTML missing")
        }

        throw FakeBookingComError.unexpectedCall("fetchInPageText url \(urlString)")
    }

    func fetchAuthenticatedText(
        url: URL,
        method: String,
        accept: String,
        referer: String?,
        contentType: String?,
        body: Data?,
        headers: [String: String]
    ) async throws -> String {
        let urlString = url.absoluteString
        if urlString == "https://secure.booking.com/dml/graphql" {
            if authenticatedThrowsForGraphQL {
                throw FakeBookingComError.graphqlFailed
            }
            // In our hotspot tests we usually don't need auth fallback for GraphQL.
            throw FakeBookingComError.unexpectedCall("auth fetch for GraphQL not configured")
        }

        // Flight order JSON endpoint.
        if urlString.contains("https://flights.booking.com/api/order/") {
            guard let json = flightOrderJSON else {
                throw FakeBookingComError.unexpectedCall("flightOrderJSON missing")
            }
            return json
        }

        // Hotel confirmation authenticated fallback.
        if urlString.contains("confirmation.html") || urlString.contains("confirmation.de.html") {
            guard let html = hotelConfirmationHTML else {
                throw FakeBookingComError.unexpectedCall("hotelConfirmationHTML missing")
            }
            return html
        }

        // My Trips fallback (rare in these tests because we return outerHTML with csrfToken/trip_id).
        throw FakeBookingComError.unexpectedCall("unexpected authenticated fetch url \(urlString)")
    }

    private func fixtureJSON(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

final class FakeBookingComWebViewProviderSession: BookingComWebViewSession {
    let bookingComWebView: BookingComWebView

    init(bookingComWebView: BookingComWebView) {
        self.bookingComWebView = bookingComWebView
    }
}

@MainActor
struct BookingComTravelProviderHotspotsTests {
    private static let myTripsURL = URL(string: "https://secure.booking.com/mytrips.de.html")!

    private func makeMyTripsHTML(tripID: String, withActivityLinks: Bool) -> String {
        // `trip_id=(\d{6,})` for preferredTripIDs.
        if withActivityLinks {
            return """
            <html><body>
              <script>
                var payload = {
                  "csrfToken": "eyJhbGciOiJIUzI1NiJ9.fake.token",
                  "ignored": "not-used-by-SSOT"
                };
              </script>
              <div>b-trips-frontend-trip-xp-mfeABC123</div>
              <div>trip_id=\(tripID)</div>
              <a href="https://www.booking.com/hotel/de/hotelname.de.html" data-start="2026-08-01" data-end="2026-08-05">Hotel</a>
            </body></html>
            """
        }
        return """
        <html><body>
          <script>
            var payload = {
              "csrfToken": "eyJhbGciOiJIUzI1NiJ9.fake.token",
              "ignored": "not-used-by-SSOT"
            };
          </script>
          <div>b-trips-frontend-trip-xp-mfeABC123</div>
          <div>trip_id=\(tripID)</div>
        </body></html>
        """
    }

    @Test("BookingComTravelProvider fetchCatalog: GraphQL success path executes & returns bookings")
    func fetchCatalog_graphQLSuccess_returnsBookings() async throws {
        let fake = FakeBookingComWebView(url: Self.myTripsURL)
        fake.outerHTML = makeMyTripsHTML(tripID: "306712048518231", withActivityLinks: false)
        fake.hotelConfirmationHTML = try fixtureText("hotel_confirmation_sample.html")
        fake.flightOrderJSON = try fixtureText("flight_order_sample.json")

        let session = FakeBookingComWebViewProviderSession(bookingComWebView: fake)
        let provider = BookingComTravelProvider()

        let catalog = try await provider.fetchCatalog(session: session)
        #expect(!catalog.bookings.isEmpty)
        #expect(catalog.bookings.contains(where: { $0.bookingType == .flight }))
        #expect(catalog.bookings.contains(where: { $0.bookingType == .hotel }))
    }

    @Test("BookingComTravelProvider fetchCatalog: GraphQL failure triggers HTML fallback (trip_ids present)")
    func fetchCatalog_graphQLFailure_fallsBackToHTML() async throws {
        let fake = FakeBookingComWebView(url: Self.myTripsURL)
        fake.outerHTML = makeMyTripsHTML(tripID: "306712048518231", withActivityLinks: true)
        fake.hotelConfirmationHTML = try fixtureText("hotel_confirmation_sample.html")

        fake.inPageThrowsForGraphQL = true
        fake.authenticatedThrowsForGraphQL = true

        let session = FakeBookingComWebViewProviderSession(bookingComWebView: fake)
        let provider = BookingComTravelProvider()

        let catalog = try await provider.fetchCatalog(session: session)
        #expect(!catalog.bookings.isEmpty)
        #expect(catalog.bookings.allSatisfy { $0.provider == .booking })
    }

    @Test("BookingComTravelProvider fetchCatalog: GraphQL failure + HTML fallback empty throws lastGraphQLError")
    func fetchCatalog_graphQLFailure_fallbackEmpty_throws() async {
        let fake = FakeBookingComWebView(url: Self.myTripsURL)
        fake.outerHTML = makeMyTripsHTML(tripID: "306712048518231", withActivityLinks: false)

        fake.inPageThrowsForGraphQL = true
        fake.authenticatedThrowsForGraphQL = true

        let session = FakeBookingComWebViewProviderSession(bookingComWebView: fake)
        let provider = BookingComTravelProvider()

        do {
            _ = try await provider.fetchCatalog(session: session)
            #expect(false)
        } catch let error as FakeBookingComError {
            #expect(error == .graphqlFailed)
        } catch {
            #expect(false)
        }
    }

    @Test("BookingComTravelProvider enrichBooking: flight confirmation loads order JSON → enrichment mapping")
    func enrichFlight_mapsOrderJSON() async throws {
        let fake = FakeBookingComWebView(url: Self.myTripsURL)
        fake.flightOrderJSON = try fixtureText("flight_order_sample.json")

        let session = FakeBookingComWebViewProviderSession(bookingComWebView: fake)
        let provider = BookingComTravelProvider()

        let ref = ProviderBookingRef(
            externalUrl: "https://flights.booking.com/confirmation/testtoken",
            bookingType: .flight
        )

        let enrichment = try await provider.enrichBooking(session: session, ref: ref)
        #expect(enrichment.rateDetails?.baggageInfoRaw?.contains("Aufgabe") == true)
        #expect(enrichment.flightDepartureOffsetSeconds == 7 * 3600)
        #expect(enrichment.flightArrivalOffsetSeconds == 8 * 3600)
    }

    @Test("BookingComTravelProvider enrichBooking: hotel confirmation loads HTML → deadlines + rateDetails")
    func enrichHotel_loadsConfirmationHTML() async throws {
        let fake = FakeBookingComWebView(url: Self.myTripsURL)
        fake.hotelConfirmationHTML = try fixtureText("hotel_confirmation_sample.html")

        let session = FakeBookingComWebViewProviderSession(bookingComWebView: fake)
        let provider = BookingComTravelProvider()

        let ref = ProviderBookingRef(
            externalUrl: "https://secure.booking.com/confirmation.de.html",
            bookingType: .hotel,
            hotelOffsetSeconds: 2 * 3600
        )

        let enrichment = try await provider.enrichBooking(session: session, ref: ref)
        #expect(enrichment.deadlines.count == 2)
        #expect(enrichment.hotelOffsetSeconds == 2 * 3600)
        #expect(enrichment.rateDetails?.roomCategory == "Zweibettzimmer")
    }

    private func fixtureText(_ name: String) throws -> String {
        let url = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures")
            .appendingPathComponent(name)
        return try String(contentsOf: url, encoding: .utf8)
    }
}

