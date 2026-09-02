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
    /// Create-Draft in der mittleren Timeline (AX ≠ Selection-ID, Surface-getrennt).
    public static let bookingCreateDraftTimeline = "reisen.booking.create-draft.timeline"
    /// Create-Draft unter dem Trip in der Sidebar.
    public static let bookingCreateDraftSidebar = "reisen.booking.create-draft.sidebar"
    public static let deleteTripMenu = "reisen.action.delete-trip"
    public static let deleteBookingMenu = "reisen.action.delete-booking"
    /// Chevron zum Ausklappen von Sidebar-Outline-Kindern (Trip oder Offene-Mailbox).
    public static let sidebarExpandBookings = "reisen.action.expand-sidebar-bookings"
    public static let splitDivider = "reisen.split.divider"
    public static let tripDeleteDialog = "reisen.dialog.delete-trip"
    public static let tripMultiSelectionSummary = "reisen.trip.multi-selection-summary"
    public static let openBookingsContent = "reisen.open-bookings.content"

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

    /// Open-/Elapsed-Mailbox-Zeile in der mittleren Liste — getrennt von Sidebar-`bookingRow`.
    public static func contentOpenBookingRow(_ id: UUID) -> String {
        "reisen.content.open-booking.\(id.uuidString)"
    }

    public static func providerRow(_ rawValue: String) -> String {
        "reisen.provider.\(rawValue)"
    }

    public static var seededTripRow: String {
        tripRow(UITestingSeed.tripID)
    }

    public static var seededTripRow2: String {
        tripRow(UITestingSeed.tripID2)
    }

    public static var seededBookingRow: String {
        bookingRow(UITestingSeed.bookingID)
    }

    public static var seededOpenBookingRow: String {
        bookingRow(UITestingSeed.openBookingID)
    }

    public static var seededOpenBookingRow2: String {
        bookingRow(UITestingSeed.openBookingID2)
    }

    public static var seededOpenBookingRow3: String {
        bookingRow(UITestingSeed.openBookingID3)
    }

    public static var seededContentOpenBookingRow2: String {
        contentOpenBookingRow(UITestingSeed.openBookingID2)
    }

    /// Seed-Titel für Content-Queries (nicht L10n; UITesting-Fixture).
    public static var seededOpenBookingTitle2: String {
        UITestingSeed.openBookingTitle2
    }

    public static var seededTimelineBookingRow: String {
        timelineBookingRow(UITestingSeed.bookingID)
    }

    public static var seededTimelineBookingRow2: String {
        timelineBookingRow(UITestingSeed.bookingID2)
    }

    /// Menütitel für Timeline-`forSelectionType`-Reach.
    ///
    /// Nicht `L10n.string` im Test-Host: der Runner kann en_US sein, während die
    /// UITesting-App deutsch startet — sonst schlägt Title-Match auf CI fehl.
    public static let deleteBookingMenuTitleDE = "Löschen…"
    public static let removeFromTripMenuTitleDE = "Von Reise entfernen…"
    public static let copyConfirmationMenuTitleDE = "Buchungsnr. kopieren"
}
