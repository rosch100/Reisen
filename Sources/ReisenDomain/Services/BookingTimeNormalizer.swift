import Foundation

/// Normalizes booking wall-clock times into stable absolute instants using stored offsets.
public struct BookingTimeNormalizer: Sendable {
    public init() {}

    /// Returns an updated booking when normalization can be applied; otherwise returns the input unchanged.
    public func normalizePendingIfPossible(_ booking: Booking) -> Booking {
        switch booking.bookingType {
        case .hotel:
            return normalizeHotel(booking)

        case .flight, .ferry:
            guard booking.timesNormalized != true else { return booking }
            return normalizeFlightOrFerry(booking)

        case .other:
            return booking
        }
    }

    private func normalizeHotel(_ booking: Booking) -> Booking {
        var updated = booking

        // Start/Ende: nur Kalenderdatum. Uhrzeit/TZ verwerfen.
        // Check-in/out-Uhrzeiten bleiben in hotelCheckInMinutes/hotelCheckOutMinutes.
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
            updated.timesSourceFingerprint = Self.hotelFingerprint(
                rawStartAt: rawStartAt,
                rawEndAt: rawEndAt,
                hotelOffsetSeconds: offsetSeconds,
                checkInMinutes: checkIn,
                checkOutMinutes: checkOut
            )
        }
        updated.timesNormalized = true

        let bookingHotelOffsetSeconds = booking.hotelOffsetSeconds ?? 0
        updated.cancellationDeadlines = booking.cancellationDeadlines.map { deadline in
            var d = deadline
            if d.hotelOffsetSeconds == nil {
                d.hotelOffsetSeconds = bookingHotelOffsetSeconds
            }
            return d
        }

        return updated
    }

    private func normalizeFlightOrFerry(_ booking: Booking) -> Booking {
        guard let depOffsetSeconds = booking.flightDepartureOffsetSeconds,
              let arrOffsetSeconds = booking.flightArrivalOffsetSeconds else {
            return booking
        }
        var updated = booking
        let rawStartAt = booking.startAt
        let rawEndAt = booking.endAt
        updated.startAt = rawStartAt.addingTimeInterval(TimeInterval(-depOffsetSeconds))
        updated.endAt = rawEndAt.addingTimeInterval(TimeInterval(-arrOffsetSeconds))
        updated.timesSourceFingerprint = Self.flightFingerprint(
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

    public static func hotelFingerprint(
        rawStartAt: Date,
        rawEndAt: Date,
        hotelOffsetSeconds: Int,
        checkInMinutes: Int,
        checkOutMinutes: Int
    ) -> String {
        "hotel|\(Int(rawStartAt.timeIntervalSince1970))|\(Int(rawEndAt.timeIntervalSince1970))|\(hotelOffsetSeconds)|\(checkInMinutes)|\(checkOutMinutes)"
    }

    public static func flightFingerprint(
        rawStartAt: Date,
        rawEndAt: Date,
        flightDepartureOffsetSeconds: Int,
        flightArrivalOffsetSeconds: Int,
        locationFrom: String?,
        locationTo: String?
    ) -> String {
        let from = locationFrom ?? ""
        let to = locationTo ?? ""
        return "flight|\(Int(rawStartAt.timeIntervalSince1970))|\(Int(rawEndAt.timeIntervalSince1970))|\(flightDepartureOffsetSeconds)|\(flightArrivalOffsetSeconds)|\(from)|\(to)"
    }
}
