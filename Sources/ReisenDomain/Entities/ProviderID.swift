import Foundation

/// Stable identifier for a travel data provider (canonical domain concept).
public struct ProviderID: RawRepresentable, Hashable, Sendable, Codable, CustomStringConvertible {
    public let rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(_ rawValue: String) {
        self.rawValue = rawValue
    }

    public var description: String { rawValue }

    public static let check24 = ProviderID(rawValue: "check24")
    public static let opodo = ProviderID(rawValue: "opodo")
    public static let booking = ProviderID(rawValue: "booking")
    public static let airbnb = ProviderID(rawValue: "airbnb")
    /// Lokale / benutzerdefinierte Buchung (wird nicht über Provider-Sync ersetzt).
    public static let manual = ProviderID(rawValue: "manual")
}
