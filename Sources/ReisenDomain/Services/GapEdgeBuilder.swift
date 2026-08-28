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
        return (0..<(sorted.count - 1)).compactMap { index in
            let from = sorted[index]
            let to = sorted[index + 1]
            return edgeGap(
                start: from.endAt,
                end: to.startAt,
                from: from,
                to: to,
                isTripBoundary: false
            )
        }
    }
}
