import Foundation

public enum BookingTimeNormalizeDispatch {
    public static func normalize(_ booking: Booking) -> Booking {
        if booking.bookingType == .hotel {
            return BookingHotelTimeNormalizer.normalize(booking)
        }
        guard booking.bookingType.usesFlightLikeSchedule else {
            return booking
        }
        guard booking.timesNormalized != true else { return booking }
        return BookingFlightTimeNormalizer.normalize(booking)
    }
}
