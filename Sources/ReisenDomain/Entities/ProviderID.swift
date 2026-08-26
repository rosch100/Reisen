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

    /// Produktname für UI und Fehlermeldungen (SSOT).
    public var displayName: String {
        switch self {
        case .check24: return "Check24"
        case .opodo: return "Opodo"
        case .booking: return "Booking.com"
        case .airbnb: return "Airbnb"
        case .getYourGuide: return "GetYourGuide"
        case .traveloka: return "Traveloka"
        case .manual: return "Manuell"
        default: return rawValue
        }
    }

    public static let check24 = ProviderID(rawValue: "check24")
    public static let opodo = ProviderID(rawValue: "opodo")
    public static let booking = ProviderID(rawValue: "booking")
    public static let airbnb = ProviderID(rawValue: "airbnb")
    public static let getYourGuide = ProviderID(rawValue: "getyourguide")
    public static let traveloka = ProviderID(rawValue: "traveloka")
    /// Lokale / benutzerdefinierte Buchung (wird nicht über Provider-Sync ersetzt).
    public static let manual = ProviderID(rawValue: "manual")

    /// Registrierte Sync-Provider (SSOT; muss der App-Registry entsprechen).
    public static let syncProviderIDs: [ProviderID] = [
        .check24, .opodo, .booking, .airbnb, .getYourGuide, .traveloka,
    ]
}
