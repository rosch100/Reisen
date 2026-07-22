import Foundation
import ReisenDomain

extension Notification.Name {
    static let reisenShowProviderSync = Notification.Name("reisenShowProviderSync")
    static let reisenSyncAllProviders = Notification.Name("reisenSyncAllProviders")
    static let reisenNewTrip = Notification.Name("reisenNewTrip")
    static let reisenAddBooking = Notification.Name("reisenAddBooking")
    static let reisenAssignBookings = Notification.Name("reisenAssignBookings")
    static let reisenEditSelectedTrip = Notification.Name("reisenEditSelectedTrip")
    static let reisenSyncCurrentProvider = Notification.Name("reisenSyncCurrentProvider")
    static let reisenRequestRemoveBookingFromTrip = Notification.Name("reisenRequestRemoveBookingFromTrip")
    static let reisenRequestDeleteManualBooking = Notification.Name("reisenRequestDeleteManualBooking")
}

enum SidebarSelection: Hashable, Identifiable {
    case trips
    case providerSync(ProviderID)
    /// Reise in der Content-/Detail-Spalte.
    case trip(UUID)
    /// „Mailbox“ für offene Buchungen (Content-Spalte).
    case openBookings

    var id: String {
        switch self {
        case .trips:
            return "trips"
        case .openBookings:
            return "openBookings"
        case .providerSync(let providerID):
            return "providerSync:\(providerID.rawValue)"
        case .trip(let uuid):
            return uuid.uuidString
        }
    }

    var tripID: UUID? {
        if case .trip(let id) = self { return id }
        return nil
    }
}
