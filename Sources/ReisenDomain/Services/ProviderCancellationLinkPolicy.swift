import Foundation

public enum ProviderCancellationLinkMode: Equatable, Sendable {
    case distinctURL
    case inPageOnOpen
    case sessionBoundDistinct
    case none
}

public enum ProviderCancellationLinkPolicy {
    public static func mode(provider: ProviderID, bookingType: BookingType) -> ProviderCancellationLinkMode {
        switch provider {
        case .traveloka:
            return .distinctURL
        case .airbnb:
            return bookingType == .activity ? .distinctURL : .none
        case .getYourGuide:
            return .inPageOnOpen
        case .billigerMietwagen:
            return .sessionBoundDistinct
        case .check24, .opodo, .booking, .manual:
            return .none
        default:
            return .none
        }
    }

    public static func requiresProviderSession(_ mode: ProviderCancellationLinkMode) -> Bool {
        switch mode {
        case .inPageOnOpen, .sessionBoundDistinct: return true
        case .distinctURL, .none: return false
        }
    }

    public static func requiresProviderSession(
        provider: ProviderID,
        bookingType: BookingType
    ) -> Bool {
        requiresProviderSession(mode(provider: provider, bookingType: bookingType))
    }
}
