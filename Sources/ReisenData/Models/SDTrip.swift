import Foundation
import SwiftData
import ReisenDomain

@Model
public final class SDTrip {
    public var id: UUID = UUID()
    public var title: String = ""
    public var startDate: Date = Date(timeIntervalSince1970: 0)
    public var endDate: Date = Date(timeIntervalSince1970: 0)
    public var destination: String?
    public var notes: String?

    @Relationship(deleteRule: .nullify, inverse: \SDBooking.trip)
    public var bookings: [SDBooking]? = []

    @Relationship(deleteRule: .cascade, inverse: \SDGap.trip)
    public var gaps: [SDGap]? = []

    public init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        destination: String? = nil,
        notes: String? = nil,
        bookings: [SDBooking] = [],
        gaps: [SDGap] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.destination = destination
        self.notes = notes
        self.bookings = bookings
        self.gaps = gaps
    }
}
