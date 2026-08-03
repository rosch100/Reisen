import Foundation

public enum CancellationDeadlineFutureFilter {
    public static func futureSorted(
        _ deadlines: [CancellationDeadline],
        now: Date
    ) -> [CancellationDeadline] {
        CancellationDeadlineFutureSort.futureSorted(deadlines, now: now)
    }

    public static func applyingPaidFilter(
        futureDeadlines: [CancellationDeadline]
    ) -> [CancellationDeadline] {
        let freeDeadlines = futureDeadlines.filter(\.isFreeCancellation)
        let paidDeadlines = futureDeadlines.filter { !$0.isFreeCancellation }
        let paidIdsToShow = CancellationDeadlinePaidFilter.idsUnderFullPrice(in: paidDeadlines)

        if paidDeadlines.compactMap(\.cancellationFeeAmount).isEmpty {
            return freeDeadlines
        }

        return CancellationDeadlinePaidApply.filter(
            futureDeadlines: futureDeadlines,
            paidIdsToShow: paidIdsToShow
        )
    }
}
