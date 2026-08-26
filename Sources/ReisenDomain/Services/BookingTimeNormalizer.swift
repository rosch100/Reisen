import Foundation

/// Normalizes booking wall-clock times into stable absolute instants using stored offsets.
public struct BookingTimeNormalizer: Sendable {
    public init() {}

    /// Returns an updated booking when normalization can be applied; otherwise returns the input unchanged.
    public func normalizePendingIfPossible(_ booking: Booking) -> Booking {
        BookingTimeNormalizeDispatch.normalize(booking)
    }

    public static func hotelFingerprint(
        rawStartAt: Date,
        rawEndAt: Date,
        hotelOffsetSeconds: Int,
        checkInMinutes: Int,
        checkOutMinutes: Int
    ) -> String {
        BookingTimeFingerprints.hotel(
            rawStartAt: rawStartAt,
            rawEndAt: rawEndAt,
            hotelOffsetSeconds: hotelOffsetSeconds,
            checkInMinutes: checkInMinutes,
            checkOutMinutes: checkOutMinutes
        )
    }

    public static func flightFingerprint(
        rawStartAt: Date,
        rawEndAt: Date,
        flightDepartureOffsetSeconds: Int,
        flightArrivalOffsetSeconds: Int,
        locationFrom: String?,
        locationTo: String?
    ) -> String {
        BookingTimeFingerprints.flight(
            rawStartAt: rawStartAt,
            rawEndAt: rawEndAt,
            flightDepartureOffsetSeconds: flightDepartureOffsetSeconds,
            flightArrivalOffsetSeconds: flightArrivalOffsetSeconds,
            locationFrom: locationFrom,
            locationTo: locationTo
        )
    }
}
