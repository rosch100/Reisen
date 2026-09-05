import Foundation

public enum BookingFlightTimeNormalizer {
    public static func normalize(_ booking: Booking) -> Booking {
        var updated = booking

        if booking.timesNormalized != true,
           let depOffsetSeconds = booking.flightDepartureOffsetSeconds,
           let arrOffsetSeconds = booking.flightArrivalOffsetSeconds {
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
        }

        // Bekannten Abflug-Offset auf Fristen übernehmen — kein `0`/`TimeZone.current`.
        if let depOffsetSeconds = booking.flightDepartureOffsetSeconds {
            updated.cancellationDeadlines = updated.cancellationDeadlines.map { deadline in
                var d = deadline
                if d.hotelOffsetSeconds == nil {
                    d.hotelOffsetSeconds = depOffsetSeconds
                }
                return d
            }
        }
        return updated
    }
}
