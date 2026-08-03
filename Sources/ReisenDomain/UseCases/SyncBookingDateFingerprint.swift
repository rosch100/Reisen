import Foundation

public struct SyncBookingDateFingerprintKey: Hashable, Sendable {
    public let bookingType: BookingType
    public let startDay: Date
    public let endDay: Date

    public init(bookingType: BookingType, startDay: Date, endDay: Date) {
        self.bookingType = bookingType
        self.startDay = startDay
        self.endDay = endDay
    }
}

public enum SyncBookingDayBounds {
    public static func dayBounds(
        calendar: Calendar,
        bookingType: BookingType,
        startAt: Date,
        endAt: Date,
        hotelOffsetSeconds: Int?
    ) -> (Date, Date) {
        if bookingType == .hotel {
            return (
                HotelStayDate.dateOnly(fromStoredOrParsed: startAt, legacyHotelOffsetSeconds: hotelOffsetSeconds),
                HotelStayDate.dateOnly(fromStoredOrParsed: endAt, legacyHotelOffsetSeconds: hotelOffsetSeconds)
            )
        }
        return (calendar.startOfDay(for: startAt), calendar.startOfDay(for: endAt))
    }
}

public enum SyncBookingDateFingerprint {
    public static func key(
        for draft: ProviderBookingDraft,
        calendar: Calendar,
        normalizer: BookingTimeNormalizer
    ) -> SyncBookingDateFingerprintKey {
        var temp = Booking(
            provider: draft.provider,
            bookingType: draft.bookingType,
            startAt: draft.startAt,
            endAt: draft.endAt
        )
        temp.hotelOffsetSeconds = draft.hotelOffsetSeconds
        temp.hotelCheckInMinutes = draft.hotelCheckInMinutes
        temp.hotelCheckOutMinutes = draft.hotelCheckOutMinutes
        temp.timesNormalized = false

        let normalized = normalizer.normalizePendingIfPossible(temp)
        let bounds = SyncBookingDayBounds.dayBounds(
            calendar: calendar,
            bookingType: normalized.bookingType,
            startAt: normalized.startAt,
            endAt: normalized.endAt,
            hotelOffsetSeconds: normalized.hotelOffsetSeconds
        )
        return SyncBookingDateFingerprintKey(
            bookingType: normalized.bookingType,
            startDay: bounds.0,
            endDay: bounds.1
        )
    }

    public static func key(for booking: Booking, calendar: Calendar) -> SyncBookingDateFingerprintKey {
        let bounds = SyncBookingDayBounds.dayBounds(
            calendar: calendar,
            bookingType: booking.bookingType,
            startAt: booking.startAt,
            endAt: booking.endAt,
            hotelOffsetSeconds: booking.hotelOffsetSeconds
        )
        return SyncBookingDateFingerprintKey(
            bookingType: booking.bookingType,
            startDay: bounds.0,
            endDay: bounds.1
        )
    }
}
