import Foundation

public struct GapDetector: Sendable {
    public var minGap: TimeInterval

    public init(minGap: TimeInterval = 12 * 60 * 60) {
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
