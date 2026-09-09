import Foundation
import ReisenDomain

/// Expedia.de car cancel assist on manage-booking (DE labels from HAR).
public enum ExpediaCarCancelAssist {
    public static let component = "ExpediaCarCancelAssist"
    public static let portalHost = ExpediaSessionProbe.portalHost

    public static func shouldRun(
        provider: ProviderID,
        loadedURL: URL?,
        bookingType: BookingType?
    ) -> Bool {
        guard provider == .expedia else { return false }
        guard bookingType == .carRental else { return false }
        return isManageBookingURL(loadedURL)
    }

    public static func isManageBookingURL(_ url: URL?) -> Bool {
        ExpediaSessionProbe.isManageBookingURL(url)
    }
}
