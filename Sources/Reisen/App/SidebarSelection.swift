import Foundation
import ReisenAppCore
import ReisenDomain

extension Notification.Name {
    static let reisenShowProviderSync = Notification.Name("reisenShowProviderSync")
    static let reisenSyncAllProviders = Notification.Name("reisenSyncAllProviders")
    static let reisenNewTrip = Notification.Name("reisenNewTrip")
    static let reisenNewTripFromOpenBookings = Notification.Name("reisenNewTripFromOpenBookings")
    static let reisenAddBooking = Notification.Name("reisenAddBooking")
    static let reisenPasteBooking = Notification.Name("reisenPasteBooking")
    static let reisenPasteBookingFromFile = Notification.Name("reisenPasteBookingFromFile")
    static let reisenAssignBookings = Notification.Name("reisenAssignBookings")
    static let reisenEditSelectedTrip = Notification.Name("reisenEditSelectedTrip")
    static let reisenSyncCurrentProvider = Notification.Name("reisenSyncCurrentProvider")
    static let reisenRequestRemoveBookingFromTrip = Notification.Name("reisenRequestRemoveBookingFromTrip")
    static let reisenRequestDeleteBooking = Notification.Name("reisenRequestDeleteBooking")
    static let reisenPresentBookingCancel = Notification.Name("reisenPresentBookingCancel")
}

enum SidebarSelection: Hashable, Identifiable {
    case trips
    case providerSync(ProviderID)
    /// Reise in der Content-/Detail-Spalte.
    case trip(UUID)
    /// „Mailbox“ für offene Buchungen (Content-Spalte).
    case openBookings
    /// Offene Buchungen, deren Datum bereits vergangen ist.
    case elapsedOpenBookings

    var id: String {
        switch self {
        case .trips:
            return "trips"
        case .openBookings:
            return "openBookings"
        case .elapsedOpenBookings:
            return "elapsedOpenBookings"
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

    /// Einstieg eines hier ausgelösten Paste-Imports; alles außerhalb einer Reise bleibt offen.
    var pasteImportEntry: PasteImportEntry {
        switch self {
        case .trip(let id):
            return .trip(id)
        case .trips, .providerSync, .openBookings, .elapsedOpenBookings:
            return .open
        }
    }
}
