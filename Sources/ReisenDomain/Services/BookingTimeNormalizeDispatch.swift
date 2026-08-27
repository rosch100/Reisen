import Foundation

public enum BookingTimeNormalizeDispatch {
    public static func normalize(_ booking: Booking) -> Booking {
        switch booking.bookingType {
        case .hotel:
            return BookingHotelTimeNormalizer.normalize(booking)

        case .flight, .ferry:
            guard booking.timesNormalized != true else { return booking }
            return BookingFlightTimeNormalizer.normalize(booking)

        case .activity, .carRental, .other:
            return booking
        }
    }
}
