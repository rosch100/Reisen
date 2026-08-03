import Foundation

public enum CancellationUrgencyDays {
    public static let criticalDaysInclusive = 2
    public static let warningDaysInclusive = 4
    private static let secondsPerDay: TimeInterval = 86_400

    public static func wholeDaysLeft(until deadlineAt: Date, now: Date) -> Int {
        Int((deadlineAt.timeIntervalSince(now) / secondsPerDay).rounded(.down))
    }

    public static func classify(daysLeft: Int) -> CancellationUrgency {
        if daysLeft <= criticalDaysInclusive { return .critical }
        if daysLeft <= warningDaysInclusive { return .warning }
        return .ok
    }
}
