import Foundation

enum GetYourGuideProviderError: Error, LocalizedError, Equatable {
    case missingWebViewSession
    case initialStateNotFound
    case myBookingsNotFound
    case bookingSummaryNotFound
    case invalidBookingURL

    var errorDescription: String? {
        switch self {
        case .missingWebViewSession:
            return "GetYourGuide benötigt eine WKWebView-basierte Session."
        case .initialStateNotFound:
            return "GetYourGuide: window.__INITIAL_STATE__ nicht gefunden."
        case .myBookingsNotFound:
            return "GetYourGuide: myBookings nicht gefunden."
        case .bookingSummaryNotFound:
            return "GetYourGuide: bookingSummary nicht gefunden."
        case .invalidBookingURL:
            return "GetYourGuide: Ungültige Buchungs-URL."
        }
    }
}
