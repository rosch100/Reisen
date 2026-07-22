import Foundation

public enum CancellationUrgency: Equatable, Sendable {
    case fix
    case critical
    case warning
    case ok

    public var label: String {
        switch self {
        case .fix: return "Fix"
        case .critical: return "Rot"
        case .warning: return "Orange"
        case .ok: return ""
        }
    }
}

public struct CancellationUrgencyService: Sendable {
    public init() {}

    public func urgency(for deadline: CancellationDeadline, now: Date = Date()) -> CancellationUrgency {
        guard deadline.isFreeCancellation else { return .fix }
        guard deadline.deadlineAt > now else { return .fix }

        let secondsLeft = deadline.deadlineAt.timeIntervalSince(now)
        let daysLeft = Int((secondsLeft / 86_400).rounded(.down))
        if daysLeft <= 2 { return .critical }
        if daysLeft <= 4 { return .warning }
        return .ok
    }
}
