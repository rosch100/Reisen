import Foundation
import ReisenDomain
import ReisenProviders

/// Extracts prep-relevant hints from Booking.com confirmation HTML.
public struct BookingComGuestHintParser: Sendable {
    public init() {}

    public func parse(from html: String) -> [BookingGuestHint] {
        StayHintHTMLExtractor.extract(from: html, providerRaw: ProviderID.booking.rawValue)
    }
}
