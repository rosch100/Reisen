import Foundation

public enum CancellationDeadlineDesiredKeys {
    public static func desiredKeys(
        tripID: UUID,
        deadlines: [CancellationDeadline],
        bookingsByID: [UUID: Booking],
        leadTimesDays: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Set<CancellationDeadlineKeying.LinkKey> {
        let leadTimes = leadTimesDays.sorted().filter { $0 > 0 }
        guard !leadTimes.isEmpty else { return [] }

        var desired: Set<CancellationDeadlineKeying.LinkKey> = []

        for deadline in deadlines where deadline.isFreeCancellation {
            guard let bookingID = deadline.bookingID,
                  let booking = bookingsByID[bookingID],
                  booking.tripID == tripID else { continue }

            CancellationDeadlineLeadKeys.insertFutureLeads(
                deadline: deadline,
                leadTimes: leadTimes,
                now: now,
                calendar: calendar,
                into: &desired
            )
        }

        return desired
    }
}
