import Foundation
import ReisenProviders

enum BilligerMietwagenProviderError: Error, LocalizedError, Equatable {
    case missingWebViewSession
    case sessionNotAuthenticated
    case tokenRefreshFailed
    case invalidBookingURL
    case catalogPaginationLimitExceeded

    var errorDescription: String? {
        let host = BilligerMietwagenAuthConstants.portalHost
        let access = BilligerMietwagenAuthConstants.accessTokenField
        let sessionFile = BilligerMietwagenAuthConstants.sessionURL.lastPathComponent
        switch self {
        case .missingWebViewSession:
            return "\(host) benötigt eine WKWebView-basierte Session."
        case .sessionNotAuthenticated:
            return "\(host): nicht angemeldet (\(sessionFile) ohne \(access))."
        case .tokenRefreshFailed:
            return "\(host): \(access) konnte nicht erneuert werden (\(BilligerMietwagenAuthConstants.refreshTokenURL.lastPathComponent))."
        case .invalidBookingURL:
            return "\(host): Ungültige Buchungs-URL."
        case .catalogPaginationLimitExceeded:
            return "\(host): Buchungsliste hat unerwartet viele Seiten (Pagination-Abbruch)."
        }
    }
}
