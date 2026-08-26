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
            guard let fireAt = LeadTimesDays.fireAt(
                referenceDate: deadline.deadlineAt,
                leadDays: leadDays,
                calendar: calendar
            ) else { continue }
            guard LeadTimesDays.isFuture(fireAt, now: now) else { continue }
            desired.insert(
                CancellationDeadlineKeying.LinkKey(
                    cancellationDeadlineID: deadline.id,
                    leadDays: leadDays
                )
            )
        }
    }
}
