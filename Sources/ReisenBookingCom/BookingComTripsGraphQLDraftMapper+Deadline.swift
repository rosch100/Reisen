import Foundation
import ReisenDomain
import ReisenDiagnostics

extension BookingComTripsGraphQLParser {
    func deadline(from policy: GraphQLPolicy?, hotelOffsetSeconds: Int?) -> CancellationDeadline? {
        guard let policy, policy.type?.uppercased() == "CANCELLATION" else { return nil }
        guard let offset = hotelOffsetSeconds else {
            if policy.message != nil || policy.name != nil {
                recordDeadlineSkipped(reason: "missing_hotel_offset")
            }
            return nil
        }
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

    private func isFreeCancellationPolicy(message: String, policyName: String?) -> Bool {
        message.lowercased().contains("kostenlos")
            || (policyName?.lowercased().contains("kostenlos") ?? false)
    }

    private func recordDeadlineSkipped(reason: String) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .booking,
                        operation: "booking_com_catalog"
                    ),
                    component: "BookingComTripsGraphQLParser",
                    phase: "deadline",
                    event: "deadline_skipped",
                    result: .skipped,
                    reason: reason,
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
