import Foundation

public enum ProviderCancellationLinkMode: Equatable, Sendable {
    case distinctURL
    case inPageOnOpen
    case sessionBoundDistinct
    case none
}

public enum ProviderCancellationLinkPolicy {
    public static func mode(provider: ProviderID, bookingType: BookingType) -> ProviderCancellationLinkMode {
        switch (provider, bookingType) {
        case (.manual, _):
            return .distinctURL
        case (.traveloka, _):
            return .distinctURL
        case (.airbnb, .activity), (.airbnb, .hotel):
            return .distinctURL
        case (.getYourGuide, _), (.billigerMietwagen, _), (.opodo, _):
            return .inPageOnOpen
        case (.expedia, .hotel):
            return .distinctURL
        case (.expedia, .carRental), (.expedia, .flight), (.expedia, .activity):
            return .inPageOnOpen
        case (.check24, _):
            return .distinctURL
        case (.booking, .hotel):
            return .distinctURL
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
