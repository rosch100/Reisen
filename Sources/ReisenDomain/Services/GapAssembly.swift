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
        if let leading = edges.edgeGap(start: tripStart, end: first.startAt, from: first, to: first) {
            results.append(leading)
        }
        results.append(contentsOf: edges.interBookingGaps(in: sorted))
        if let trailing = edges.edgeGap(start: last.endAt, end: tripEnd, from: last, to: last) {
            results.append(trailing)
        }
        return results
    }
}
