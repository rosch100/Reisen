import Foundation

/// Baut einzelne Gap-Kanten für `GapDetector` (SSOT).
public struct GapEdgeBuilder: Sendable {
    public var minGap: TimeInterval

    public init(minGap: TimeInterval) {
        self.minGap = minGap
    }

    public func edgeGap(
        start: Date,
        end: Date,
        from: Booking,
        to: Booking,
        isTripBoundary: Bool
    ) -> ComputedGap? {
        guard end.timeIntervalSince(start) >= minGap else { return nil }
        return ComputedGap(
            gapStart: start,
            gapEnd: end,
            kind: GapKindClassifier.classify(from: from.bookingType, to: to.bookingType),
            fromBooking: from,
            toBooking: to,
            isTripBoundary: isTripBoundary
        )
    }

    public func interBookingGaps(in sorted: [Booking]) -> [ComputedGap] {
        guard sorted.count >= 2 else { return [] }
        return (0..<(sorted.count - 1)).flatMap { index in
            interGaps(from: sorted[index], to: sorted[index + 1])
        }
    }

    /// Bei Ortswechsel: Übernachtung über den vollen Bogen (Checkout→Check-in),
    /// Transport am letzten Tag der Übernachtungslücke; ohne Übernachtung Transport am Tag dazwischen.
    private func interGaps(from: Booking, to: Booking) -> [ComputedGap] {
        let start = from.endAt
        let end = to.startAt
        guard end.timeIntervalSince(start) >= 0 else { return [] }

        guard SpatialGapDetector.placesDiffer(from: from, to: to) else {
            if let gap = edgeGap(
                start: start,
                end: end,
                from: from,
                to: to,
                isTripBoundary: false
            ) {
                return [gap]
            }
            return []
        }

        var gaps: [ComputedGap] = []
        if end.timeIntervalSince(start) >= minGap {
            gaps.append(
                ComputedGap(
                    gapStart: start,
                    gapEnd: end,
                    kind: .lodging,
                    fromBooking: from,
                    toBooking: to,
                    isTripBoundary: false
                )
            )
            let transport = transportOnLastLodgingDay(from: from, to: to, lodgingEnd: end)
            if transport.gapEnd.timeIntervalSince(transport.gapStart) > 0
                || transport.gapStart == end
            {
                // Positivdauer oder bewusster Midnight-/Kalendertag-Marker am Lodging-Ende.
                gaps.append(transport)
            }
        } else if end.timeIntervalSince(start) > 0 {
            gaps.append(
                ComputedGap(
                    gapStart: start,
                    gapEnd: end,
                    kind: .transport,
                    fromBooking: from,
                    toBooking: to,
                    isTripBoundary: false
                )
            )
        }
        return gaps
    }

    /// Transport-Marker am Kalendertag des Übernachtungs-Endes (Check-in nächste Unterkunft).
    private func transportOnLastLodgingDay(from: Booking, to: Booking, lodgingEnd: Date) -> ComputedGap {
        let dayStart = HotelStayDate.dateOnly(
            fromStoredOrParsed: lodgingEnd,
            legacyHotelOffsetSeconds: to.hotelOffsetSeconds ?? from.hotelOffsetSeconds
        )
        let transportStart = max(from.endAt, min(dayStart, lodgingEnd))
        return ComputedGap(
            gapStart: transportStart,
            gapEnd: lodgingEnd,
            kind: .transport,
            fromBooking: from,
            toBooking: to,
            isTripBoundary: false
        )
    }
}
