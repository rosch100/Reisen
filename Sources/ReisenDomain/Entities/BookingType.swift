import Foundation

public enum BookingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case hotel
    case ferry
    case activity
    case other

    public var id: String { rawValue }

    /// UI-Label (Editor, Listen, Details).
    public var displayLabel: String {
        switch self {
        case .flight: return "Flug"
        case .hotel: return "Hotel"
        case .ferry: return "Fähre"
        case .activity: return "Erlebnis"
        case .other: return "Sonstiges"
        }
    }
}
