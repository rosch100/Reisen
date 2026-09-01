import Foundation

/// Kalendertag-Span einer Buchung für Überschneidungschecks (ohne SwiftData).
public struct BookingDaySpan: Equatable, Sendable, Identifiable {
    public let id: UUID
    public let startAt: Date
    public let endAt: Date
    /// Ortsschlüssel (`locationTo` sonst `locationFrom`); leer = kein Mehrfachzimmer-Match.
    public let placeKey: String
    public let tripID: UUID?
    public let bookingType: BookingType

    public init(
        id: UUID,
        startAt: Date,
        endAt: Date,
        placeKey: String,
        tripID: UUID?,
        bookingType: BookingType
    ) {
        self.id = id
        self.startAt = startAt
        self.endAt = endAt
        self.placeKey = placeKey
        self.tripID = tripID
        self.bookingType = bookingType
    }
}

public extension Booking {
    var daySpan: BookingDaySpan {
        BookingDaySpan(
            id: id,
            startAt: startAt,
            endAt: endAt,
            placeKey: locationTo ?? locationFrom ?? "",
            tripID: tripID,
            bookingType: bookingType
        )
    }
}
