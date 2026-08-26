import Foundation

public enum CancellationDeadlinePaidApply {
    public static func filter(
        futureDeadlines: [CancellationDeadline],
        paidIdsToShow: Set<UUID>
    ) -> [CancellationDeadline] {
        futureDeadlines.filter { deadline in
            deadline.isFreeCancellation || paidIdsToShow.contains(deadline.id)
        }
    }
}
