import Foundation

public struct CancellationUrgencyService: Sendable {
    public static let criticalDaysInclusive = CancellationUrgencyDays.criticalDaysInclusive
    public static let warningDaysInclusive = CancellationUrgencyDays.warningDaysInclusive

    public init() {}

    public func urgency(for deadline: CancellationDeadline, now: Date = Date()) -> CancellationUrgency {
        guard deadline.isFreeCancellation, deadline.deadlineAt > now else { return .fix }
        return CancellationUrgencyDays.classify(
            daysLeft: CancellationUrgencyDays.wholeDaysLeft(until: deadline.deadlineAt, now: now)
        )
    }

    public func urgency(daysLeft: Int) -> CancellationUrgency {
        CancellationUrgencyDays.classify(daysLeft: daysLeft)
    }
}
