import Foundation

public enum BookingType: String, Codable, CaseIterable, Identifiable, Sendable {
    case flight
    case hotel
    case ferry
    case activity
    case carRental
    case other

    public var id: String { rawValue }

    /// UI-Label (Editor, Listen, Details).
    public var displayLabel: String {
        L10n.bookingTypeDisplay(self)
    }

    /// Fallback-Titel wenn `Booking.title` fehlt (Sync/Side-Effects, kompakte Listen).
    public var defaultDisplayTitle: String {
        rawValue.capitalized
    }
}
