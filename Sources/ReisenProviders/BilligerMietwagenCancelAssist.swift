import Foundation
import ReisenDomain

/// One-shot SPA assist: booking detail → scoped cancel form (BM).
///
/// Cold `/reservation/cancellation` is a guest lookup; scoped cancel needs the detail-page
/// click. Assist failure leaves the booking page (in-page fallback).
public enum BilligerMietwagenCancelAssist {
    public static let component = "BilligerMietwagenCancelAssist"

    public static func shouldRun(provider: ProviderID, loadedURL: URL?) -> Bool {
        guard provider == .billigerMietwagen else { return false }
        return isBookingDetailURL(loadedURL)
    }

    public static func isBookingDetailURL(_ url: URL?) -> Bool {
        guard let url, let host = url.host, BilligerMietwagenAuthConstants.isPortalHost(host) else {
            return false
        }
        let path = url.path
        guard path.contains(BilligerMietwagenAuthConstants.accountBookingsPath) else {
            return false
        }
        return !path.contains(BilligerMietwagenAuthConstants.cancellationPath)
    }

    public static func isCancellationPath(_ url: URL?) -> Bool {
        guard let url, let host = url.host, BilligerMietwagenAuthConstants.isPortalHost(host) else {
            return false
        }
        return url.path.contains(BilligerMietwagenAuthConstants.cancellationPath)
    }
}
