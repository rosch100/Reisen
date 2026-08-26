import Foundation

/// Identity keys for pre-travel hint reminders (push + EventKit).
public enum PreTravelHintKeying {
    public struct LinkKey: Hashable, Equatable, Sendable {
        public let bookingID: UUID
        public let leadDays: Int

        public init(bookingID: UUID, leadDays: Int) {
            self.bookingID = bookingID
            self.leadDays = leadDays
        }
    }

    public struct NotificationKey: Hashable, Equatable, Sendable {
        public let bookingID: UUID
        public let fireAt: Date

        public init(bookingID: UUID, fireAt: Date) {
            self.bookingID = bookingID
            self.fireAt = fireAt
        }
    }

    public static func notificationDesiredKeys(
        bookings: [Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Set<NotificationKey> {
        Set(
            PreTravelHintNotificationItems.items(
                bookings: bookings,
                bookingTitles: bookingTitles,
                leadTimes: leadTimes,
                now: now,
                calendar: calendar
            ).map(\.notificationKey)
        )
    }

    public static func desiredKeys(
        tripID: UUID,
        bookings: [Booking],
        leadTimesDays: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> Set<LinkKey> {
        PreTravelHintDesiredKeys.desiredKeys(
            tripID: tripID,
            bookings: bookings,
            leadTimesDays: leadTimesDays,
            now: now,
            calendar: calendar
        )
    }

    public static func unwantedKeys(existing: Set<LinkKey>, desired: Set<LinkKey>) -> Set<LinkKey> {
        existing.subtracting(desired)
    }
}

extension PreTravelHintKeying.LinkKey {
    public init(link: PreTravelHintLink) {
        self.init(bookingID: link.ownerBookingID, leadDays: link.leadDays)
    }
}

extension PreTravelHintKeying.NotificationKey {
    public init?(reminder: Reminder) {
        guard let bookingID = reminder.bookingID else { return nil }
        self.init(bookingID: bookingID, fireAt: reminder.fireAt)
    }
}
