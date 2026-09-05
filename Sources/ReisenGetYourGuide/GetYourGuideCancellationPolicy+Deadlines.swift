import Foundation
import ReisenDomain

extension GYGCancellationPolicy {
    static func deadlines(_ policy: GYGCancellationPolicy?) -> [CancellationDeadline] {
        policy?.asDeadlines() ?? []
    }

    private func asDeadlines() -> [CancellationDeadline] {
        let raw = NonEmpty.string(expirationDate) ?? NonEmpty.string(policyExpirationDate)
        guard let raw, let deadlineAt = ISODateTime.parseInstant(raw) else { return [] }
        let typeHaystack = [type, policyType]
            .compactMap { $0?.lowercased() }
            .joined(separator: " ")
        let isFree = typeHaystack.contains("freecancellation")
            || (feeValue.map { $0 == 0 } ?? false)
        return [
            CancellationDeadline(
                deadlineAt: deadlineAt,
                policyText: message,
                isFreeCancellation: isFree,
                hotelOffsetSeconds: ISODateTime.offsetSeconds(from: raw)
            ),
        ]
    }
}
