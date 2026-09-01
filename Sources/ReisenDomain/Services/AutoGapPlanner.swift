import Foundation

public enum AutoGapPlanner {
    public static func plan(
        tripStart: Date,
        tripEnd: Date,
        bookings: [Booking]
    ) -> [AutoGapDesired] {
        let real = bookings.filter(\.isRealForGapDetect).sorted { $0.startAt < $1.startAt }
        guard !real.isEmpty else { return [] }

        var byKey: [String: AutoGapDesired] = [:]

        let temporalGaps = GapDetector().computeGaps(
            bookings: real,
            tripStart: tripStart,
            tripEnd: tripEnd
        ).filter { !$0.isTripBoundary }

        for gap in temporalGaps {
            let kind = gap.kind
            guard kind == .lodging || kind == .both else { continue }
            let key = AutoGapIdentity.key(from: gap.fromBooking.id, to: gap.toBooking.id, role: .lodging)
            let hints = GapContext(
                gapStart: gap.gapStart,
                gapEnd: gap.gapEnd,
                kind: kind,
                fromLocationFrom: gap.fromBooking.locationFrom,
                fromLocationTo: gap.fromBooking.locationTo,
                toLocationFrom: gap.toBooking.locationFrom,
                toLocationTo: gap.toBooking.locationTo
            )
            byKey[key] = AutoGapDesired(
                identityKey: key,
                role: .lodging,
                bookingType: .hotel,
                startAt: gap.gapStart,
                endAt: gap.gapEnd,
                locationFrom: hints.destinationHint,
                locationTo: hints.destinationHint,
                fromBookingID: gap.fromBooking.id,
                toBookingID: gap.toBooking.id
            )
        }

        for spatial in SpatialGapDetector.detect(sortedReal: real) {
            byKey[spatial.identityKey] = spatial
        }

        return byKey.values.sorted {
            if $0.startAt != $1.startAt { return $0.startAt < $1.startAt }
            return $0.identityKey < $1.identityKey
        }
    }
}
