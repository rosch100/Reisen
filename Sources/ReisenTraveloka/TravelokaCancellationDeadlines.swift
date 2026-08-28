import Foundation
import ReisenDomain

enum TravelokaCancellationDeadlines {
    static func free(
        local: String,
        timeZone: TimeZone,
        policyText: String = "Free cancellation"
    ) -> CancellationDeadline? {
        guard let date = TravelokaJSON.localDateTime(local, timeZone: timeZone) else { return nil }
        return CancellationDeadline(
            deadlineAt: date,
            policyText: policyText,
            isFreeCancellation: true,
            hotelOffsetSeconds: timeZone.secondsFromGMT(for: date)
        )
    }

    static func fee(
        local: String,
        timeZone: TimeZone,
        policyText: String,
        feeAmount: Double?
    ) -> CancellationDeadline? {
        guard let date = TravelokaJSON.localDateTime(local, timeZone: timeZone) else { return nil }
        return CancellationDeadline(
            deadlineAt: date,
            policyText: policyText,
            isFreeCancellation: false,
            hotelOffsetSeconds: timeZone.secondsFromGMT(for: date),
            cancellationFeeAmount: feeAmount
        )
    }

    static func at(
        _ date: Date,
        timeZone: TimeZone,
        policyText: String,
        isFreeCancellation: Bool,
        feeAmount: Double? = nil
    ) -> CancellationDeadline {
        CancellationDeadline(
            deadlineAt: date,
            policyText: policyText,
            isFreeCancellation: isFreeCancellation,
            hotelOffsetSeconds: timeZone.secondsFromGMT(for: date),
            cancellationFeeAmount: isFreeCancellation ? nil : feeAmount
        )
    }
}
