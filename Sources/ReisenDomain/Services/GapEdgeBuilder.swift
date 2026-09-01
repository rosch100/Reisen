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

    /// Bei Ortswechsel: Transport-Segment (≤1 Tag) + optionales Lodging für den Rest (≥ minGap).
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
        let transportEnd = SpatialGapDetector.cappedTransportEnd(fromStart: start, intervalEnd: end)
        if transportEnd.timeIntervalSince(start) > 0 {
            gaps.append(
                ComputedGap(
                    gapStart: start,
                    gapEnd: transportEnd,
                    kind: .transport,
                    fromBooking: from,
                    toBooking: to,
                    isTripBoundary: false
                )
            )
        }
        if end.timeIntervalSince(transportEnd) >= minGap {
            gaps.append(
                ComputedGap(
                    gapStart: transportEnd,
                    gapEnd: end,
                    kind: .lodging,
                    fromBooking: from,
                    toBooking: to,
                    isTripBoundary: false
                )
            )
        }
        return gaps
    }
}
