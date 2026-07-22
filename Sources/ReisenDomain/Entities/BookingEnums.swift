import Foundation

public enum BookingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case hotel
    case ferry
    case other

    public var id: String { rawValue }
}

public enum BookingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case confirmed
    case cancelled
    case unknown

    public var id: String { rawValue }
}

public enum TravellerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case adult
    case child
    case infant
    case unknown

    public var id: String { rawValue }
}

public enum BaggageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkedBag
    case cabinBag
    case personalItem
    case unknown

    public var id: String { rawValue }
}

public enum BookingBoardType: String, Codable, CaseIterable, Identifiable, Sendable {
    case roomOnly
    case breakfastIncluded
    case halfBoard
    case fullBoard
    case unknown

    public var id: String { rawValue }
}

public enum GapKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case lodging
    case transport
    case both

    public var id: String { rawValue }
}

public enum ReminderTarget: String, Codable, CaseIterable, Identifiable, Sendable {
    case cancellationDeadline
    case gap
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
