import Foundation

public enum ReminderTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case cancellationDeadline
    case gap
    case preTravelHints
    case custom

    public var id: String { rawValue }
}

public enum ReminderChannel: String, Codable, CaseIterable, Identifiable, Sendable {
    case notification
    case calendar

    public var id: String { rawValue }
}

public enum ReminderStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case scheduled
    case fired
    case cancelled

    public var id: String { rawValue }
}
