import Foundation
import ReisenDomain

extension DomainMapper {
    public static func deadline(from model: SDCancellationDeadline) -> CancellationDeadline {
        CancellationDeadline(
            id: model.id,
            deadlineAt: model.deadlineAt,
            policyText: model.policyText,
            isStrict: model.isStrict,
            isFreeCancellation: model.isFreeCancellation,
            hotelOffsetSeconds: model.hotelOffsetSeconds,
            cancellationFeeAmount: model.cancellationFeeAmount,
            bookingID: model.booking?.id
        )
    }
}
