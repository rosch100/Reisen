import Foundation

public enum CancellationDeadlineLeadKeys {
    public static func insertFutureLeads(
        deadline: CancellationDeadline,
        leadTimes: [Int],
        now: Date,
        calendar: Calendar,
        into desired: inout Set<CancellationDeadlineKeying.LinkKey>
    ) {
        for leadDays in leadTimes {
            guard let fireAt = calendar.date(byAdding: .day, value: -leadDays, to: deadline.deadlineAt) else {
                continue
            }
            if fireAt <= now { continue }
            desired.insert(
                CancellationDeadlineKeying.LinkKey(
                    cancellationDeadlineID: deadline.id,
                    leadDays: leadDays
                )
            )
        }
    }
}
