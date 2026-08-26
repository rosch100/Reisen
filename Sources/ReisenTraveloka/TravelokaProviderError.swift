import Foundation

public enum TravelokaProviderError: Error, LocalizedError, Sendable {
    case missingWebViewSession
    case invalidResponse
    case missingBookingIdentifiers
    case missingItineraryTimestamps
    case requestBodyEncodingFailed
    case invalidBookingURL
    case missingSessionSentinel

    public var errorDescription: String? {
        switch self {
        case .missingWebViewSession:
            return "Traveloka benötigt eine WKWebView-Session."
        case .invalidResponse:
            return "Traveloka-Antwort konnte nicht gelesen werden."
        case .missingBookingIdentifiers:
            return "Traveloka-Buchung ohne bookingId/itineraryId."
        case .missingItineraryTimestamps:
            return "Traveloka-Buchung ohne Start-/Endzeit."
        case .requestBodyEncodingFailed:
            return "Traveloka-Request-Body konnte nicht serialisiert werden."
        case .invalidBookingURL:
            return "Traveloka Detail-URL ungültig."
        case .missingSessionSentinel:
            return "Traveloka-Session ohne Sentinel-Cookie (sen_t) — bitte erneut anmelden."
        }
    }
}
