import Foundation

public struct GapDetector: Sendable {
    /// SSOT: Mindestlänge für zeitliche Lücken (Leading/Inter/Trailing).
    public static let defaultMinGap: TimeInterval = 12 * 60 * 60

    public var minGap: TimeInterval

    public init(minGap: TimeInterval = GapDetector.defaultMinGap) {
        self.minGap = minGap
    }

    public func computeGaps(bookings: [Booking]) -> [ComputedGap] {
        guard let bounds = GapTripWindow.bounds(from: bookings) else { return [] }
        return computeGaps(bookings: bookings, tripStart: bounds.start, tripEnd: bounds.end)
    }

    public func computeGaps(bookings: [Booking], tripStart: Date, tripEnd: Date) -> [ComputedGap] {
        let sorted = bookings.sorted { $0.startAt < $1.startAt }
        return GapAssembly.assemble(
            sorted: sorted,
            tripStart: tripStart,
            tripEnd: tripEnd,
            minGap: minGap
        )
    }
}
