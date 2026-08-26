import Foundation

public enum CancellationDeadlinePaidFilter {
    /// Paid-Deadlines unter der maximalen Fee (Vollpreis wird ausgeblendet).
    public static func idsUnderFullPrice(in paidDeadlines: [CancellationDeadline]) -> Set<UUID> {
        let paidAmounts = paidDeadlines.compactMap(\.cancellationFeeAmount)
        guard let bookingPriceFee = paidAmounts.max() else { return [] }

        let epsilon = 0.01
        return Set(
            paidDeadlines.compactMap { deadline -> UUID? in
                guard let amount = deadline.cancellationFeeAmount else { return nil }
                return amount < (bookingPriceFee - epsilon) ? deadline.id : nil
            }
        )
    }
}
