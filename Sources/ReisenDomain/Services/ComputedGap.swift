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

    /// Stable key for persistence/UI matching (integer epoch seconds — SSOT).
    public var identityKey: String {
        let start = Int(gapStart.timeIntervalSince1970)
        let end = Int(gapEnd.timeIntervalSince1970)
        return "\(fromBooking.id.uuidString)|\(toBooking.id.uuidString)|\(start)|\(end)"
    }

    public var timelineItemID: String {
        "gap|\(identityKey)"
    }

    /// Leading/Trailing aus `GapAssembly` (from == to). Inter-Booking sonst.
    public var isTripBoundary: Bool {
        fromBooking.id == toBooking.id
    }
}
