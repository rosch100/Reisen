import Foundation
import ReisenDomain

extension BookingComFlightOrderParser {
    func deadlines(from options: FlightCancellationOptions?) -> [CancellationDeadline] {
        guard let options, options.cancellable == true else { return [] }
        let mapped = (options.refundOptions ?? []).compactMap { refund in
            deadline(from: refund, options: options)
        }
        return mapped.sorted { $0.deadlineAt < $1.deadlineAt }
    }

    func deadline(
        from refund: FlightRefundOption,
        options: FlightCancellationOptions
    ) -> CancellationDeadline? {
        guard let raw = refund.deadlineAt ?? refund.expiresAt,
              let date = BookingComParsing.parseISODateTime(raw) else { return nil }
        return CancellationDeadline(
            deadlineAt: date,
            policyText: refund.description,
            isStrict: true,
            isFreeCancellation: options.isFullRefund == true || refund.isFullRefund == true,
            cancellationFeeAmount: refund.feeAmount
        )
    }
}
