import Foundation

public enum BaggageType: String, Codable, CaseIterable, Identifiable, Sendable {
    case checkedBag
    case cabinBag
    case personalItem
    case unknown

    public var id: String { rawValue }
}
