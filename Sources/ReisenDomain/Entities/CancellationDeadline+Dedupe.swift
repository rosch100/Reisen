import Foundation

extension CancellationDeadline {
    public static func uniquenessKey(
        deadlineAt: Date,
        isFreeCancellation: Bool,
        isStrict: Bool,
        cancellationFeeAmount: Double?,
        policyText: String?
    ) -> String {
        let feeKey = cancellationFeeAmount.map { String(Int(($0 * 100).rounded())) }
            ?? policyText?.lowercased()
            ?? ""
        return "\(Int(deadlineAt.timeIntervalSince1970))|\(isFreeCancellation)|\(isStrict)|\(feeKey)"
    }

    public var uniquenessKey: String {
        Self.uniquenessKey(
            deadlineAt: deadlineAt,
            isFreeCancellation: isFreeCancellation,
            isStrict: isStrict,
            cancellationFeeAmount: cancellationFeeAmount,
            policyText: policyText
        )
    }
}

extension Array where Element == CancellationDeadline {
    /// Gleiche Frist nach Zeitpunkt, Free/Fee, Strict und Betrag/Policy-Text.
    public var deduped: [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for deadline in self {
            byKey[deadline.uniquenessKey] = deadline
        }
        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }
}
