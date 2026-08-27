import Foundation

extension Array where Element == CancellationDeadline {
    public var firstHotelOffsetSeconds: Int? {
        compactMap(\.hotelOffsetSeconds).first
    }

    /// Neueste freie Frist, sonst die volle Liste.
    public var preferringLatestFree: [CancellationDeadline] {
        let latestFree = filter(\.isFreeCancellation).max(by: { $0.deadlineAt < $1.deadlineAt })
        if let latestFree {
            return [latestFree]
        }
        return self
    }

    /// Refund ergänzt fehlende Fristen; vorhandene Free-/Fee-Fristen bleiben.
    public func combining(refund: [CancellationDeadline]) -> [CancellationDeadline] {
        preferring(filter(\.isFreeCancellation), else: refund.filter(\.isFreeCancellation))
            + preferring(filter { !$0.isFreeCancellation }, else: refund.filter { !$0.isFreeCancellation })
    }

    private func preferring(
        _ existing: [CancellationDeadline],
        else refund: [CancellationDeadline]
    ) -> [CancellationDeadline] {
        existing.isEmpty ? refund : existing
    }
}
