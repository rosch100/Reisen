import Foundation
import ReisenData
import ReisenDomain

/// Stabile Accessibility-Identifier für XCUI (nicht L10n).
public enum UITestingIdentifiers {
    public static let sidebar = "reisen.sidebar"
    public static let detail = "reisen.detail"
    public static let tripOverview = "reisen.trip.overview"
    public static let tripOverviewTitle = "reisen.trip.overview.title"
    public static let inspector = "reisen.inspector"
    public static let settings = "reisen.settings"
    public static let syncChrome = "reisen.sync.chrome"
    public static let syncLoginChrome = "reisen.sync.login-chrome"
    /// Passkey-Hinweis im Sync-Login-Chrome (nur bei Apple-IdP sichtbar).
    public static let syncApplePasskeyHint = "reisen.sync.apple-passkey-hint"
    /// Hauptfläche: gewähltes Portal ist deaktiviert (Checkbox aus).
    public static let syncProviderDisabledEmpty = "reisen.sync.provider-disabled-empty"
    public static let syncFillCredentials = "reisen.sync.fill-credentials"
    public static let syncRememberLogin = "reisen.sync.remember-login"
    public static let syncRememberLoginSheet = "reisen.sync.remember-login.sheet"
    public static let syncRememberLoginUsername = "reisen.sync.remember-login.username"
    public static let syncRememberLoginPassword = "reisen.sync.remember-login.password"
    public static let syncRememberLoginUnderstood = "reisen.sync.remember-login.understood"
    public static let syncRememberLoginCancel = "reisen.sync.remember-login.cancel"
    public static let syncOpenPasswords = "reisen.sync.open-passwords"
    public static let syncBrowserCollapse = "reisen.sync.browser-collapse"
    public static let syncProviderWebView = "reisen.sync.provider-webview"
    public static let bookingEditor = "reisen.booking.editor"
    public static let bookingEditorSave = "reisen.booking.editor.save"
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
    public static let openBookingMultiSelectionSummary = "reisen.open.multi-selection-summary"
    public static let tripBookingMultiSelectionSummary = "reisen.trip-booking.multi-selection-summary"
    public static let openBookingsContent = "reisen.open-bookings.content"
    public static let openBookingsMailbox = "reisen.open-bookings.mailbox"
    public static let elapsedOpenBookingsMailbox = "reisen.elapsed-open-bookings.mailbox"
    public static let tripEditor = "reisen.trip.editor"
    public static let tripEditorTitleField = "reisen.trip.editor.title"
    public static let tripEditorSave = "reisen.trip.editor.save"
    public static let assignBookingsSheet = "reisen.assign-bookings.sheet"
    public static let assignBookingsConfirm = "reisen.assign-bookings.confirm"
    public static let assignBookingsAction = "reisen.action.assign-bookings"

    public static func assignBookingsCandidate(_ id: UUID) -> String {
        "reisen.assign-bookings.candidate.\(id.uuidString)"
    }

    /// First-Launch Provider-Setup (Spec: `setup.providers.*`).
    public static let providerSetupSheet = "setup.providers.sheet"
    public static let providerSetupContinue = "setup.providers.continue"
    /// „Ohne Buchungsportale“ (historischer Identifier `setup.providers.later`).
    public static let providerSetupLater = "setup.providers.later"
    public static let providerSetupReopen = "setup.providers.reopen"
    public static let settingsHideProviderSetupToggle = "reisen.settings.hide-provider-setup"

    public static func providerSetupToggle(_ providerID: ProviderID) -> String {
        "setup.providers.toggle.\(providerID.rawValue)"
    }
    public static let gapEditor = "reisen.gap.editor"
    public static let gapEditorTitleField = "reisen.gap.editor.title"
    public static let gapEditAction = "reisen.gap.edit"
    public static let gapEditorSave = "reisen.gap.editor.save"
    public static let emptyStateNewTrip = "reisen.empty-state.new-trip"
    public static let bookingEditorTitle = "reisen.booking.editor.title"
    public static let settingsNotificationToggle = "reisen.settings.notification-toggle"
    public static let settingsAppIconPicker = "reisen.settings.app-icon-picker"
    public static let settingsICloudSyncToggle = "reisen.settings.icloud-sync-toggle"
    public static let pasteImportReview = "reisen.paste-import.review"
    public static let pasteImportAccept = "reisen.paste-import.accept"
    public static let bookingDetailEdit = "reisen.booking.detail.edit"

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

    /// Sidebar-Checkbox: Provider für Login/Sync aktivieren/deaktivieren.
    public static func providerEnableToggle(_ rawValue: String) -> String {
        "reisen.provider.enable.\(rawValue)"
    }

    public static func gapRow(timelineItemID: String) -> String {
        "reisen.gap.\(timelineItemID)"
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

    public static var seededBookingRow2: String {
        bookingRow(UITestingSeed.bookingID2)
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

    public static var seededGapRow: String {
        gapRow(timelineItemID: UITestingSeed.seededGapTimelineItemID)
    }

    /// Menütitel für Timeline-`forSelectionType`-Reach.
    ///
    /// Nicht `L10n.string` im Test-Host: der Runner kann en_US sein, während die
    /// UITesting-App deutsch startet — sonst schlägt Title-Match auf CI fehl.
    public static let deleteBookingMenuTitleDE = "Löschen…"
    public static let deleteTripMenuTitleDE = "Reise löschen…"
    public static let removeFromTripMenuTitleDE = "Von Reise entfernen…"
    public static let copyConfirmationMenuTitleDE = "Buchungsnummer kopieren"
    public static let newTripMenuTitleDE = "Neue Reise…"
    public static let assignBookingsMenuTitleDE = "Buchungen zuordnen…"
    public static let editGapMenuTitleDE = "Lücke bearbeiten…"
    public static let editTripMenuTitleDE = "Reise bearbeiten…"
    public static let syncAllMenuTitleDE = "Alle aktualisieren"
    public static let syncCurrentMenuTitleDE = "Aktuelles Portal aktualisieren"
}
