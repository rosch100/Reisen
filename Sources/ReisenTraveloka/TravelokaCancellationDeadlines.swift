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

    /// Refund-HTML ergänzt fehlende Fristen; vorhandene Free-Frist aus dem Itinerary bleibt.
    static func combining(
        existing: [CancellationDeadline],
        refund: [CancellationDeadline]
    ) -> [CancellationDeadline] {
        preferring(existing.filter(\.isFreeCancellation), else: refund.filter(\.isFreeCancellation))
            + preferring(existing.filter { !$0.isFreeCancellation }, else: refund.filter { !$0.isFreeCancellation })
    }

    private static func preferring(
        _ existing: [CancellationDeadline],
        else refund: [CancellationDeadline]
    ) -> [CancellationDeadline] {
        existing.isEmpty ? refund : existing
    }
}
