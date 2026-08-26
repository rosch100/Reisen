import Foundation
import ReisenDomain

extension BookingComTripsGraphQLParser {
    func deadline(from policy: GraphQLPolicy?, hotelOffsetSeconds: Int?) -> CancellationDeadline? {
        guard let policy, policy.type?.uppercased() == "CANCELLATION" else { return nil }
        guard let offset = hotelOffsetSeconds else { return nil }
        guard let message = policy.message,
              let date = BookingComParsing.parseExclusiveGermanPolicyDate(
                in: message,
                offsetSeconds: offset
              ) else {
            return nil
        }
        let isFree = isFreeCancellationPolicy(message: message, policyName: policy.name)
        return CancellationDeadline(
            deadlineAt: date,
            policyText: message,
            isStrict: true,
            isFreeCancellation: isFree,
            hotelOffsetSeconds: offset,
            cancellationFeeAmount: isFree ? 0 : nil
        )
    }

    func isFreeCancellationPolicy(message: String, policyName: String?) -> Bool {
        message.lowercased().contains("kostenlos")
            || (policyName?.lowercased().contains("kostenlos") ?? false)
    }
}
