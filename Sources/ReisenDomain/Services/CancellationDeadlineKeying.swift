import Foundation

/// Pure helper for computing identity keys used to upsert/delete
/// EventKit EKEvent/EKReminder items for cancellation deadlines.
public enum CancellationDeadlineKeying {
    public struct LinkKey: Hashable, Equatable, Sendable {
        public let cancellationDeadlineID: UUID
        public let leadDays: Int

        public init(cancellationDeadlineID: UUID, leadDays: Int) {
            self.cancellationDeadlineID = cancellationDeadlineID
            self.leadDays = leadDays
        }
    }

    /// Computes desired link keys for a given trip.
    ///
    /// Desired keys include only leadDays where the resulting fireAt is in the future.
    public static func desiredKeys(
        tripID: UUID,
        deadlines: [CancellationDeadline],
        bookingsByID: [UUID: Booking],
        leadTimesDays: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Set<LinkKey> {
        CancellationDeadlineDesiredKeys.desiredKeys(
            tripID: tripID,
            deadlines: deadlines,
            bookingsByID: bookingsByID,
            leadTimesDays: leadTimesDays,
            now: now,
            calendar: calendar
        )
    }

    public static func unwantedKeys(existing: Set<LinkKey>, desired: Set<LinkKey>) -> Set<LinkKey> {
        existing.subtracting(desired)
    }
}
