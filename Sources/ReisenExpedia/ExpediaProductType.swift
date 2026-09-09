import Foundation
import ReisenDomain

enum ExpediaProductType {
    static func bookingType(fromProductIdentifier identifier: String) -> BookingType? {
        let lower = identifier.lowercased()
        if lower.hasPrefix("eg:property:") { return .hotel }
        if lower.hasPrefix("eg:car:") { return .carRental }
        if lower.hasPrefix("eg:flight:") { return .flight }
        if lower.hasPrefix("eg:activity:") {
            return .activity
        }
        return nil
    }

    /// Car uses manage-booking as cancellation entry (live assist evidence). Flight/activity stay
    /// without catalog cancel URL until a real cancel capture exists. Hotel needs Booking-Servicing.
    static func usesManageBookingAsCancellationURL(_ bookingType: BookingType) -> Bool {
        switch bookingType {
        case .carRental:
            return true
        case .hotel, .flight, .activity, .ferry, .train, .other:
            return false
        }
    }

    static func catalogCancellationURL(
        bookingType: BookingType,
        manageURL: String?
    ) -> String? {
        guard usesManageBookingAsCancellationURL(bookingType) else { return nil }
        return manageURL
    }
}
