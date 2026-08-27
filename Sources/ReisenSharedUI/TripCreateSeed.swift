import Foundation

/// Prefilled values when creating a trip from open bookings.
public struct TripCreateSeed: Sendable, Equatable, Identifiable {
    public let id: UUID
    public var title: String?
    public var startDate: Date
    public var endDate: Date

    public init(
        id: UUID = UUID(),
        title: String?,
        startDate: Date,
        endDate: Date
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
    }
}
