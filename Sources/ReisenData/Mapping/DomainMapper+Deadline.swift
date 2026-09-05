import Foundation
import ReisenDomain

extension DomainMapper {
    /// Maps a persisted deadline. Epoch-0 defaults are invalid and omitted by callers via `compactMap`.
    public static func deadline(from model: SDCancellationDeadline) -> CancellationDeadline? {
        guard model.deadlineAt.timeIntervalSince1970 > 0 else { return nil }
        return CancellationDeadline(
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
