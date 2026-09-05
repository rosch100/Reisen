import Foundation

public enum BookingHotelTimeNormalizer {
    public static func normalize(_ booking: Booking) -> Booking {
        var updated = booking

        let rawStartAt = booking.startAt
        let rawEndAt = booking.endAt
        updated.startAt = HotelStayDate.dateOnly(
            fromStoredOrParsed: rawStartAt,
            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
        )
        updated.endAt = HotelStayDate.dateOnly(
            fromStoredOrParsed: rawEndAt,
            legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
        )

        if let checkIn = booking.hotelCheckInMinutes,
           let checkOut = booking.hotelCheckOutMinutes,
           let offsetSeconds = booking.hotelOffsetSeconds {
            updated.timesSourceFingerprint = BookingTimeNormalizer.hotelFingerprint(
                rawStartAt: rawStartAt,
                rawEndAt: rawEndAt,
                hotelOffsetSeconds: offsetSeconds,
                checkInMinutes: checkIn,
                checkOutMinutes: checkOut
            )
        }
        updated.timesNormalized = true

        // Fehlenden Offset nicht erfinden (kein `0`/`TimeZone.current`) — EventKit/Reminder skippen bei nil.
        updated.cancellationDeadlines = booking.cancellationDeadlines.map { deadline in
            var d = deadline
            if d.hotelOffsetSeconds == nil, let bookingOffset = booking.hotelOffsetSeconds {
                d.hotelOffsetSeconds = bookingOffset
            }
            return d
        }

        return updated
    }
}
