import Foundation

public struct ComputedGap: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let gapStart: Date
    public let gapEnd: Date
    public let kind: GapKind
    public let fromBooking: Booking
    public let toBooking: Booking

    public init(
        id: UUID = UUID(),
        gapStart: Date,
        gapEnd: Date,
        kind: GapKind,
        fromBooking: Booking,
        toBooking: Booking
    ) {
        self.id = id
        self.gapStart = gapStart
        self.gapEnd = gapEnd
        self.kind = kind
        self.fromBooking = fromBooking
        self.toBooking = toBooking
    }

    public var identityKey: String {
        "\(fromBooking.id.uuidString)|\(toBooking.id.uuidString)|\(gapStart.timeIntervalSince1970)|\(gapEnd.timeIntervalSince1970)"
    }
}

public struct GapDetector: Sendable {
    public var minGap: TimeInterval

    public init(minGap: TimeInterval = 12 * 60 * 60) {
        self.minGap = minGap
    }

    public func computeGaps(bookings: [Booking]) -> [ComputedGap] {
        guard let first = bookings.min(by: { $0.startAt < $1.startAt }),
              let last = bookings.max(by: { $0.endAt < $1.endAt }) else {
            return []
        }
        return computeGaps(bookings: bookings, tripStart: first.startAt, tripEnd: last.endAt)
    }

    public func computeGaps(bookings: [Booking], tripStart: Date, tripEnd: Date) -> [ComputedGap] {
        let sorted = bookings.sorted { $0.startAt < $1.startAt }
        guard let first = sorted.first, let last = sorted.last else { return [] }

        var results: [ComputedGap] = []

        let startDelta = first.startAt.timeIntervalSince(tripStart)
        if startDelta >= minGap {
            results.append(
                ComputedGap(
                    gapStart: tripStart,
                    gapEnd: first.startAt,
                    kind: classifyGap(from: first, to: first),
                    fromBooking: first,
                    toBooking: first
                )
            )
        }

        if sorted.count >= 2 {
            for index in 0..<(sorted.count - 1) {
                let from = sorted[index]
                let to = sorted[index + 1]
                let delta = to.startAt.timeIntervalSince(from.endAt)
                guard delta >= minGap else { continue }
                results.append(
                    ComputedGap(
                        gapStart: from.endAt,
                        gapEnd: to.startAt,
                        kind: classifyGap(from: from, to: to),
                        fromBooking: from,
                        toBooking: to
                    )
                )
            }
        }

        let endDelta = tripEnd.timeIntervalSince(last.endAt)
        if endDelta >= minGap {
            results.append(
                ComputedGap(
                    gapStart: last.endAt,
                    gapEnd: tripEnd,
                    kind: classifyGap(from: last, to: last),
                    fromBooking: last,
                    toBooking: last
                )
            )
        }

        return results
    }

    private func classifyGap(from: Booking, to: Booking) -> GapKind {
        if from.bookingType == .hotel || to.bookingType == .hotel {
            return .transport
        }
        if (from.bookingType == .flight || from.bookingType == .ferry)
            && (to.bookingType == .flight || to.bookingType == .ferry) {
            return .lodging
        }
        return .both
    }
}
