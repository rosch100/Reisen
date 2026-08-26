import Foundation
import SwiftData

@Model
public final class SDCalendarEventLink {
    public var id: UUID = UUID()
    public var roleRaw: String = ""
    public var ownerTripID: UUID = UUID()
    public var ownerBookingID: UUID?

    public var eventIdentifier: String = ""
    public var calendarItemExternalIdentifier: String?
    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        roleRaw: String,
        ownerTripID: UUID,
        ownerBookingID: UUID? = nil,
        eventIdentifier: String,
        calendarItemExternalIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.roleRaw = roleRaw
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.eventIdentifier = eventIdentifier
        self.calendarItemExternalIdentifier = calendarItemExternalIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}
