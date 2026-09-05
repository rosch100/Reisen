import Foundation

public enum AirbnbProviderError: LocalizedError, Sendable {
    case sessionNotEstablished

    public var errorDescription: String? {
        switch self {
        case .sessionNotEstablished:
            return "Es besteht noch keine Airbnb Session. Bitte zunächst anmelden."
        }
    }
}
