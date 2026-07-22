import Foundation

public struct CalendarEventLink: Equatable, Sendable, Identifiable {
    public var id: UUID

    public var role: CalendarEventRole

    public var ownerTripID: UUID
    public var ownerBookingID: UUID?

    /// EventKit's internal identifier (`eventIdentifier`).
    public var eventIdentifier: String
    public var calendarItemExternalIdentifier: String?

    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        role: CalendarEventRole,
        ownerTripID: UUID,
        ownerBookingID: UUID? = nil,
        eventIdentifier: String,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.role = role
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.eventIdentifier = eventIdentifier
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

