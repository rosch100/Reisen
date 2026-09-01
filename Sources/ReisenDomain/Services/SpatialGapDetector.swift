import Foundation

public enum SpatialGapDetector {
    /// SSOT: maximale Dauer einer Transport-Lücke (Auto + ComputedGap-Segment).
    public static let maxTransportDuration: TimeInterval = 24 * 60 * 60

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

    /// Beide PlaceKeys gesetzt und ungleich.
    public static func placesDiffer(from: Booking, to: Booking) -> Bool {
        guard let fromKey = PlaceKey.normalize(fromEndPlace(from)),
              let toKey = PlaceKey.normalize(toStartPlace(to))
        else { return false }
        return fromKey != toKey
    }

    public static func cappedTransportEnd(fromStart start: Date, intervalEnd: Date) -> Date {
        min(start.addingTimeInterval(maxTransportDuration), intervalEnd)
    }

    private static func transportDesired(from: Booking, to: Booking) -> AutoGapDesired? {
        guard placesDiffer(from: from, to: to) else { return nil }
        guard let type = evidencedTransportType(from: from, to: to) else { return nil }

        let start = from.endAt
        let intervalEnd = to.startAt
        guard intervalEnd.timeIntervalSince(start) >= 0 else { return nil }

        let end = cappedTransportEnd(fromStart: start, intervalEnd: intervalEnd)
        guard end.timeIntervalSince(start) > 0 else { return nil }

        return AutoGapDesired(
            identityKey: AutoGapIdentity.key(from: from.id, to: to.id, role: .transport),
            role: .transport,
            bookingType: type,
            startAt: start,
            endAt: end,
            locationFrom: fromEndPlace(from),
            locationTo: toStartPlace(to),
            fromBookingID: from.id,
            toBookingID: to.id
        )
    }

    /// Nur belegter Modus (Flug/Fähre/Offset) — kein erfundenes `.train`.
    private static func evidencedTransportType(from: Booking, to: Booking) -> BookingType? {
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
        return nil
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
