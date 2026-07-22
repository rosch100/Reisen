import Foundation

/// Persistent identity mapping between a cancellation deadline "logical key"
/// and the created EventKit EKEvent + EKReminder.
///
/// We use `(cancellationDeadlineID, leadDays)` as the logical identity so repeated
/// sync runs update instead of duplicating entries.
public struct CancellationDeadlineLink: Equatable, Sendable, Identifiable {
    public var id: UUID

    public var ownerTripID: UUID
    public var ownerBookingID: UUID?

    public var cancellationDeadlineID: UUID
    public var leadDays: Int

    public var eventIdentifier: String
    public var reminderIdentifier: String?

    public var lastSyncedAt: Date?

    public init(
        id: UUID = UUID(),
        ownerTripID: UUID,
        ownerBookingID: UUID? = nil,
        cancellationDeadlineID: UUID,
        leadDays: Int,
        eventIdentifier: String,
        reminderIdentifier: String? = nil,
        lastSyncedAt: Date? = nil
    ) {
        self.id = id
        self.ownerTripID = ownerTripID
        self.ownerBookingID = ownerBookingID
        self.cancellationDeadlineID = cancellationDeadlineID
        self.leadDays = leadDays
        self.eventIdentifier = eventIdentifier
        self.reminderIdentifier = reminderIdentifier
        self.lastSyncedAt = lastSyncedAt
    }
}

