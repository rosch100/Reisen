import Foundation
import ReisenData

/// Stabile Accessibility-Identifier für XCUI (nicht L10n).
public enum UITestingIdentifiers {
    public static let sidebar = "reisen.sidebar"
    public static let detail = "reisen.detail"
    public static let inspector = "reisen.inspector"
    public static let settings = "reisen.settings"
    public static let syncChrome = "reisen.sync.chrome"
    public static let bookingEditor = "reisen.booking.editor"
    public static let emptyState = "reisen.empty-state"
    public static let addBooking = "reisen.action.add-booking"
    public static let deleteTripMenu = "reisen.action.delete-trip"
    public static let deleteBookingMenu = "reisen.action.delete-booking"
    /// Chevron zum Ausklappen von Sidebar-Outline-Kindern (Trip oder Offene-Mailbox).
    public static let sidebarExpandBookings = "reisen.action.expand-sidebar-bookings"
    public static let splitDivider = "reisen.split.divider"
    public static let tripDeleteDialog = "reisen.dialog.delete-trip"

    public static func tripRow(_ id: UUID) -> String {
        "reisen.trip.\(id.uuidString)"
    }

    public static func bookingRow(_ id: UUID) -> String {
        "reisen.booking.\(id.uuidString)"
    }

    /// Trip-Timeline booking row (detail list) — distinct from sidebar/open `bookingRow`.
    public static func timelineBookingRow(_ id: UUID) -> String {
        "reisen.timeline.booking.\(id.uuidString)"
    }

    public static func providerRow(_ rawValue: String) -> String {
        "reisen.provider.\(rawValue)"
    }

    public static var seededTripRow: String {
        tripRow(UITestingSeed.tripID)
    }

    public static var seededBookingRow: String {
        bookingRow(UITestingSeed.bookingID)
    }

    public static var seededTimelineBookingRow: String {
        timelineBookingRow(UITestingSeed.bookingID)
    }
}
