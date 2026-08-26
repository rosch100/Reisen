import Foundation
import ReisenDomain
import ReisenProviders

@MainActor
public final class BookingComTravelProvider: TravelProvider, TravelProviderLoginConfiguration {
    public init() {}

    public var id: ProviderID { .booking }

    public var displayName: String { "Booking.com" }

    /// My Trips is the session-bound catalog surface (no public consumer Orders API).
    public var loginURL: URL {
        Self.myTripsURL
    }

    public var keychainServerHost: String { "booking.com" }

    public var onProgress: (@MainActor (String) -> Void)?

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

extension BookingComTravelProvider {
    static let myTripsURL = URL(string: "https://secure.booking.com/mytrips.de.html")!

    func webView(from session: any ProviderSession) throws -> BookingComWebView {
        guard let webSession = session as? BookingComWebViewSession else {
            throw BookingComProviderError.sessionNotEstablished
        }
        return webSession.bookingComWebView
    }
}
