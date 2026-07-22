import Foundation

public enum CalendarEventRole: String, Codable, CaseIterable, Sendable, Equatable, Identifiable {
    case tripStart
    case tripEnd
    case flightDeparture
    case flightArrival
    case hotelStay

    public var id: String { rawValue }
}

