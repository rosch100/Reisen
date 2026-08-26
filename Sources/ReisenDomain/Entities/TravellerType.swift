import Foundation

public enum TravellerType: String, Codable, CaseIterable, Identifiable, Sendable {
    case adult
    case child
    case infant
    case unknown

    public var id: String { rawValue }
}
