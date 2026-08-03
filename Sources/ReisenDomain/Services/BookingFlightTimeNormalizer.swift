import Foundation

public enum BookingFlightTimeNormalizer {
    public static func normalize(_ booking: Booking) -> Booking {
        guard let depOffsetSeconds = booking.flightDepartureOffsetSeconds,
              let arrOffsetSeconds = booking.flightArrivalOffsetSeconds else {
            return booking
        }
        var updated = booking
        let rawStartAt = booking.startAt
        let rawEndAt = booking.endAt
        updated.startAt = rawStartAt.addingTimeInterval(TimeInterval(-depOffsetSeconds))
        updated.endAt = rawEndAt.addingTimeInterval(TimeInterval(-arrOffsetSeconds))
        updated.timesSourceFingerprint = BookingTimeNormalizer.flightFingerprint(
            rawStartAt: rawStartAt,
            rawEndAt: rawEndAt,
            flightDepartureOffsetSeconds: depOffsetSeconds,
            flightArrivalOffsetSeconds: arrOffsetSeconds,
            locationFrom: booking.locationFrom,
            locationTo: booking.locationTo
        )
        updated.timesNormalized = true
        return updated
    }
}
