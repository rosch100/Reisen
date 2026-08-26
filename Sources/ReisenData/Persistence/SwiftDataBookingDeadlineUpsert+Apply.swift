import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingDeadlineUpsert {
    static func takeOrCreate(
        _ deadline: CancellationDeadline,
        from remaining: inout [SDCancellationDeadline],
        booking: SDBooking,
        in context: ModelContext
    ) -> SDCancellationDeadline {
        if let existing = SwiftDataBookingMatchHelpers.takeMatching(
            from: &remaining,
            id: deadline.id,
            idOf: \.id,
            contentMatch: {
                SwiftDataBookingContentKeys.deadline(deadlineAt: $0.deadlineAt, fee: $0.cancellationFeeAmount)
                    == SwiftDataBookingContentKeys.deadline(deadlineAt: deadline.deadlineAt, fee: deadline.cancellationFeeAmount)
            }
        ) {
            return existing
        }
        let created = SDCancellationDeadline(
            id: deadline.id,
            deadlineAt: deadline.deadlineAt,
            policyText: deadline.policyText,
            isStrict: deadline.isStrict,
            isFreeCancellation: deadline.isFreeCancellation,
            hotelOffsetSeconds: deadline.hotelOffsetSeconds,
            cancellationFeeAmount: deadline.cancellationFeeAmount,
            booking: booking
        )
        context.insert(created)
        return created
    }

    static func apply(_ deadline: CancellationDeadline, to model: SDCancellationDeadline, booking: SDBooking) {
        model.deadlineAt = deadline.deadlineAt
        model.policyText = deadline.policyText
        model.isStrict = deadline.isStrict
        model.isFreeCancellation = deadline.isFreeCancellation
        model.hotelOffsetSeconds = deadline.hotelOffsetSeconds
        model.cancellationFeeAmount = deadline.cancellationFeeAmount
        model.booking = booking
    }
}
