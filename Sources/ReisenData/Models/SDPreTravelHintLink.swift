import Foundation
import SwiftData

@Model
public final class SDPreTravelHintLink {
    public var id: UUID = UUID()
    public var ownerTripID: UUID = UUID()
    public var ownerBookingID: UUID = UUID()
    public var leadDays: Int = 0

    public var eventIdentifier: String = ""
    public var reminderIdentifier: String?

    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        ownerTripID: UUID,
        ownerBookingID: UUID,
        leadDays: Int,
        eventIdentifier: String,
        reminderIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.leadDays = leadDays
        self.eventIdentifier = eventIdentifier
        self.reminderIdentifier = reminderIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}
