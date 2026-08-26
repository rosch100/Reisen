import Foundation

public struct PreTravelHintScheduleItem: Equatable, Sendable {
    public let linkKey: PreTravelHintKeying.LinkKey
    public let booking: Booking
    public let hints: [BookingGuestHint]
    public let fireAt: Date
    public let bookingTitle: String

    public init(
        linkKey: PreTravelHintKeying.LinkKey,
        booking: Booking,
        hints: [BookingGuestHint],
        fireAt: Date,
        bookingTitle: String
    ) {
        self.linkKey = linkKey
        self.booking = booking
        self.hints = hints
        self.fireAt = fireAt
        self.bookingTitle = bookingTitle
    }
}

public struct PreTravelHintNotificationItem: Equatable, Sendable {
    public let notificationKey: PreTravelHintKeying.NotificationKey
    public let booking: Booking
    public let hints: [BookingGuestHint]
    public let fireAt: Date
    public let bookingTitle: String

    public init(
        notificationKey: PreTravelHintKeying.NotificationKey,
        booking: Booking,
        hints: [BookingGuestHint],
        fireAt: Date,
        bookingTitle: String
    ) {
        self.notificationKey = notificationKey
        self.booking = booking
        self.hints = hints
        self.fireAt = fireAt
        self.bookingTitle = bookingTitle
    }
}

public enum PreTravelHintDesiredItems {
    public static func items(
        tripID: UUID,
        bookings: [Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        now: Date,
        calendar: Calendar = .current,
        defaultBookingTitle: String = "Buchung"
    ) -> [PreTravelHintScheduleItem] {
        guard !leadTimes.isEmpty else { return [] }

        var result: [PreTravelHintScheduleItem] = []

        for booking in bookings where booking.tripID == tripID {
            let hints = booking.preTravelImportantHints
            guard !hints.isEmpty else { continue }

            let bookingTitle = bookingTitles[booking.id] ?? booking.title ?? defaultBookingTitle

            for lead in PreTravelHintLeadKeys.futureLeads(
                booking: booking,
                leadTimes: leadTimes,
                now: now,
                calendar: calendar
            ) {
                let key = PreTravelHintKeying.LinkKey(bookingID: booking.id, leadDays: lead.leadDays)
                result.append(
                    PreTravelHintScheduleItem(
                        linkKey: key,
                        booking: booking,
                        hints: hints,
                        fireAt: lead.fireAt,
                        bookingTitle: bookingTitle
                    )
                )
            }
        }

        return result
    }

    public static func itemsByKey(
        tripID: UUID,
        bookings: [Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        now: Date,
        calendar: Calendar = .current,
        defaultBookingTitle: String = "Buchung"
    ) -> [PreTravelHintKeying.LinkKey: PreTravelHintScheduleItem] {
        var byKey: [PreTravelHintKeying.LinkKey: PreTravelHintScheduleItem] = [:]
        for item in items(
            tripID: tripID,
            bookings: bookings,
            bookingTitles: bookingTitles,
            leadTimes: leadTimes,
            now: now,
            calendar: calendar,
            defaultBookingTitle: defaultBookingTitle
        ) {
            byKey[item.linkKey] = item
        }
        return byKey
    }
}

public enum PreTravelHintNotificationItems {
    public static func items(
        bookings: [Booking],
        bookingTitles: [UUID: String],
        leadTimes: [Int],
        now: Date,
        calendar: Calendar = .current,
        defaultBookingTitle: String = "Buchung"
    ) -> [PreTravelHintNotificationItem] {
        guard !leadTimes.isEmpty else { return [] }

        var result: [PreTravelHintNotificationItem] = []

        for booking in bookings {
            let hints = booking.preTravelImportantHints
            guard !hints.isEmpty else { continue }

            let bookingTitle = bookingTitles[booking.id] ?? booking.title ?? defaultBookingTitle

            for lead in PreTravelHintLeadKeys.futureLeads(
                booking: booking,
                leadTimes: leadTimes,
                now: now,
                calendar: calendar
            ) {
                result.append(
                    PreTravelHintNotificationItem(
                        notificationKey: PreTravelHintKeying.NotificationKey(
                            bookingID: booking.id,
                            fireAt: lead.fireAt
                        ),
                        booking: booking,
                        hints: hints,
                        fireAt: lead.fireAt,
                        bookingTitle: bookingTitle
                    )
                )
            }
        }

        return result
    }
}
