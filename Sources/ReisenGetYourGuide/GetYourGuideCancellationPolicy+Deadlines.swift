import Foundation
import ReisenDomain

extension GYGCancellationPolicy {
    func asDeadlines() -> [CancellationDeadline] {
        guard let deadlineAt = expirationDate ?? policyExpirationDate else { return [] }
        let typeHaystack = [type, policyType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let isFree = typeHaystack.contains("freecancellation")
            || (feeValue.map { $0 == 0 } ?? false)
        return [
            CancellationDeadline(
                deadlineAt: deadlineAt,
                policyText: message,
                isFreeCancellation: isFree
            ),
        ]
    }
}
