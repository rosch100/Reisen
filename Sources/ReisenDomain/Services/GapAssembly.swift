import Foundation

public enum GapAssembly {
    public static func assemble(
        sorted: [Booking],
        tripStart: Date,
        tripEnd: Date,
        minGap: TimeInterval
    ) -> [ComputedGap] {
        guard let first = sorted.first, let last = sorted.last else { return [] }

        let edges = GapEdgeBuilder(minGap: minGap)
        var results: [ComputedGap] = []
        // Vertrag: Trip-Rand-Gaps explizit `isTripBoundary: true` (Leading/Trailing).
        if let leading = edges.edgeGap(
            start: tripStart,
            end: first.startAt,
            from: first,
            to: first,
            isTripBoundary: true
        ) {
            results.append(leading)
        }
        results.append(contentsOf: edges.interBookingGaps(in: sorted))
        if let trailing = edges.edgeGap(
            start: last.endAt,
            end: tripEnd,
            from: last,
            to: last,
            isTripBoundary: true
        ) {
            results.append(trailing)
        }
        return results
    }
}
