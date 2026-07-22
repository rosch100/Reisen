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
        let leadTimes = leadTimesDays.sorted().filter { $0 > 0 }
        guard !leadTimes.isEmpty else { return [] }

        var desired: Set<LinkKey> = []

        for deadline in deadlines where deadline.isFreeCancellation {
            guard let bookingID = deadline.bookingID,
                  let booking = bookingsByID[bookingID],
                  booking.tripID == tripID else { continue }

            for leadDays in leadTimes {
                guard let fireAt = calendar.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else { continue }
                if fireAt <= now { continue }
                desired.insert(LinkKey(cancellationDeadlineID: deadline.id, leadDays: leadDays))
            }
        }

        return desired
    }

    public static func unwantedKeys(existing: Set<LinkKey>, desired: Set<LinkKey>) -> Set<LinkKey> {
        existing.subtracting(desired)
    }
}

