import Foundation

public enum PreTravelHintDesiredKeys {
    public static func desiredKeys(
        tripID: UUID,
        bookings: [Booking],
        leadTimesDays: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Set<PreTravelHintKeying.LinkKey> {
        let leadTimes = LeadTimesDays.normalized(leadTimesDays)
        guard !leadTimes.isEmpty else { return [] }

        return Set(
            PreTravelHintDesiredItems.items(
                tripID: tripID,
                bookings: bookings,
                bookingTitles: [:],
                leadTimes: leadTimes,
                now: now,
                calendar: calendar
            ).map(\.linkKey)
        )
    }
}
