import Foundation
import ReisenDomain

public struct BookingComActivityListParser: Sendable {
    public init() {}

    public func parseBookings(from html: String) throws -> [ProviderBookingDraft] {
        var bookings: [ProviderBookingDraft] = []
        bookings.append(contentsOf: try parseDataAttributeCards(from: html))
        if bookings.isEmpty {
            bookings.append(contentsOf: try parseJSONLDOrEmbeddedReservations(from: html))
        }
        if bookings.isEmpty {
            bookings.append(contentsOf: try parseMyTripsLinks(from: html))
        }

        // Deduplicate by external URL.
        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        let unique = Array(byURL.values).sorted { $0.startAt < $1.startAt }

        if unique.isEmpty {
            throw BookingComActivityListParserError.noBookingsFound
        }
        return unique
    }
}

public enum BookingComActivityListParserError: LocalizedError, Sendable {
    case noBookingsFound

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return "Keine Booking.com-Buchungen im HTML gefunden."
        }
    }
}
