import Foundation
import ReisenProviders

enum GetYourGuideProviderError: Error, LocalizedError, Equatable {
    case missingWebViewSession
    case sessionNotEstablished
    case initialStateNotFound
    case cloudflareChallenge
    case myBookingsNotFound
    case bookingSummaryNotFound
    case invalidBookingURL

    var errorDescription: String? {
        let name = GetYourGuideWebConstants.displayName
        switch self {
        case .missingWebViewSession:
            return "\(name) benötigt eine WKWebView-basierte Session."
        case .sessionNotEstablished:
            return "Es besteht noch keine \(name) Session. Bitte zunächst anmelden."
        case .initialStateNotFound:
            return "\(name): window.\(GetYourGuideInitialState.marker) nicht gefunden."
        case .cloudflareChallenge:
            return "\(name): Cloudflare-Challenge statt Buchungsseite."
        case .myBookingsNotFound:
            return "\(name): myBookings nicht gefunden."
        case .bookingSummaryNotFound:
            return "\(name): bookingSummary nicht gefunden."
        case .invalidBookingURL:
            return "\(name): Ungültige Buchungs-URL."
        }
    }

    static func from(_ error: AuthenticatedSessionError) -> GetYourGuideProviderError {
        switch error {
        case .challenge:
            return .cloudflareChallenge
        case .notEstablished:
            return .sessionNotEstablished
        }
    }
}
