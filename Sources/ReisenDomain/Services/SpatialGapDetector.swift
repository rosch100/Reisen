import Foundation

public enum SpatialGapDetector {
    public static func detect(sortedReal: [Booking]) -> [AutoGapDesired] {
        guard sortedReal.count >= 2 else { return [] }
        var results: [AutoGapDesired] = []
        for index in 0..<(sortedReal.count - 1) {
            let from = sortedReal[index]
            let to = sortedReal[index + 1]
            guard let desired = transportDesired(from: from, to: to) else { continue }
            results.append(desired)
        }
        return results
    }

    private static func transportDesired(from: Booking, to: Booking) -> AutoGapDesired? {
        guard let fromKey = PlaceKey.normalize(fromEndPlace(from)),
              let toKey = PlaceKey.normalize(toStartPlace(to)),
              fromKey != toKey
        else { return nil }

        let start = from.endAt
        let end = to.startAt
        guard end.timeIntervalSince(start) >= 0 else { return nil }

        let type = transportType(from: from, to: to)
        let rawFrom = fromEndPlace(from)
        let rawTo = toStartPlace(to)
        return AutoGapDesired(
            identityKey: AutoGapIdentity.key(from: from.id, to: to.id, role: .transport),
            role: .transport,
            bookingType: type,
            startAt: start,
            endAt: end,
            locationFrom: rawFrom,
            locationTo: rawTo,
            fromBookingID: from.id,
            toBookingID: to.id
        )
    }

    private static func transportType(from: Booking, to: Booking) -> BookingType {
        if from.bookingType == .flight || to.bookingType == .flight {
            return .flight
        }
        if let arrival = from.flightArrivalOffsetSeconds,
           let departure = to.flightDepartureOffsetSeconds,
           arrival != departure
        {
            return .flight
        }
        if from.bookingType == .ferry || to.bookingType == .ferry {
            return .ferry
        }
        return .train
    }

    /// Spec: locationTo → locationToAddress → locationFrom → locationFromAddress
    public static func fromEndPlace(_ booking: Booking) -> String? {
        firstNonEmpty(
            booking.locationTo,
            booking.locationToAddress,
            booking.locationFrom,
            booking.locationFromAddress
        )
    }

    /// Spec: locationFrom → locationFromAddress → locationTo → locationToAddress
    public static func toStartPlace(_ booking: Booking) -> String? {
        firstNonEmpty(
            booking.locationFrom,
            booking.locationFromAddress,
            booking.locationTo,
            booking.locationToAddress
        )
    }

    private static func firstNonEmpty(_ values: String?...) -> String? {
        for value in values {
            guard let value else { continue }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }
}
