import Foundation

/// Ephemere Vollständigkeits-Zusammenfassung einer Reise (kein Persistenzmodell).
public struct TripCompleteness: Equatable, Sendable {
    public let bookingCount: Int
    public let interBookingGapCount: Int
    /// Unique Gap-Arten der Inter-Booking-Lücken, Reihenfolge lodging → transport → both.
    public let interBookingGapKinds: [GapKind]
    public let edgeGapCount: Int
    public let unknownStatusCount: Int

    public var hasBookings: Bool { bookingCount > 0 }
    public var hasTimeGaps: Bool { interBookingGapCount > 0 }
    /// Buchungen vorhanden und keine Inter-Booking-Lücken. Unknown und Rand-Gaps blockieren nicht.
    public var isTimelineComplete: Bool { hasBookings && interBookingGapCount == 0 }

    public init(
        bookingCount: Int,
        interBookingGapCount: Int,
        interBookingGapKinds: [GapKind],
        edgeGapCount: Int,
        unknownStatusCount: Int
    ) {
        self.bookingCount = bookingCount
        self.interBookingGapCount = interBookingGapCount
        self.interBookingGapKinds = interBookingGapKinds
        self.edgeGapCount = edgeGapCount
        self.unknownStatusCount = unknownStatusCount
    }
}

/// Optionale Detail-Captions zur Completeness-Anzeige (Kind / Rand / unknown).
public struct TripCompletenessCaptionParts: Equatable, Sendable {
    public let kind: String?
    public let edge: String?
    public let unknown: String?

    public init(kind: String?, edge: String?, unknown: String?) {
        self.kind = kind
        self.edge = edge
        self.unknown = unknown
    }
}

public enum TripCompletenessCalculator {
    public static func evaluate(
        tripStart: Date,
        tripEnd: Date,
        bookings: [Booking],
        minGap: TimeInterval = GapDetector.defaultMinGap
    ) -> TripCompleteness {
        let active = bookings.filter { $0.status != .cancelled }
        let gaps = GapDetector(minGap: minGap).computeGaps(
            bookings: active,
            tripStart: tripStart,
            tripEnd: tripEnd
        )
        let inter = gaps.filter { !$0.isTripBoundary }
        let edge = gaps.filter(\.isTripBoundary)
        return TripCompleteness(
            bookingCount: active.count,
            interBookingGapCount: inter.count,
            interBookingGapKinds: uniqueKinds(in: inter),
            edgeGapCount: edge.count,
            unknownStatusCount: active.filter { $0.status == .unknown }.count
        )
    }

    private static func uniqueKinds(in gaps: [ComputedGap]) -> [GapKind] {
        let present = Set(gaps.map(\.kind))
        return GapKind.allCases.filter { present.contains($0) }
    }
}
