import SwiftUI
import AppKit
import ReisenDomain
import ReisenPasteImport
import ReisenSharedUI

struct ReisenCommands: Commands {
    @FocusedValue(\.openBookingsCommandState) private var openBookingsCommandState
    @FocusedValue(\.bookingPortalOpenCommandState) private var bookingPortalOpenCommandState
    @FocusedValue(\.appMenuCommandState) private var appMenuCommandState
    @FocusedValue(\.providerSyncCanSync) private var providerSyncCanSync
    @Environment(\.openURL) private var openURL

    /// Verfügbarkeit entscheidet über beide Einfüge-Einträge im Menü.
    ///
    /// Die Notification trägt die Modellstufe nicht mit; `PasteImportSession.start()`
    /// löst sie über `PasteImportResolvedModel.kind()` erneut auf — dieselbe Quelle, kein zweiter Pfad.
    private var pasteImportKind: PasteImportModelKind { PasteImportResolvedModel.kind() }

    private var canPerformSingleTripActions: Bool {
        appMenuCommandState?.canPerformSingleTripActions == true
    }
    private var canAssignBookings: Bool { appMenuCommandState?.canAssignBookings == true }
    private var canSyncAll: Bool { appMenuCommandState?.canSyncAll == true }
    private var canSyncCurrent: Bool { providerSyncCanSync == true }
    private var canOpenBookingPortal: Bool { bookingPortalOpenCommandState?.canOpen == true }
    private var canCancelBookingPortal: Bool { bookingPortalOpenCommandState?.canCancel == true }

    var body: some Commands {
        CommandGroup(replacing: .pasteboard) {
            Button(L10n.string(.commonCut)) {
                NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("x", modifiers: [.command])

            Button(L10n.string(.commonCopy)) {
                NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("c", modifiers: [.command])

            Button(L10n.string(.commonPaste)) {
                NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("v", modifiers: [.command])

            Button(L10n.string(.commonSelectAll)) {
                NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("a", modifiers: [.command])
        }

        CommandGroup(replacing: .newItem) {
            Button(L10n.string(.menuNewTrip)) {
                NotificationCenter.default.post(name: .reisenNewTrip, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command])

            Button(L10n.string(.menuNewTripFromSelection)) {
                NotificationCenter.default.post(name: .reisenNewTripFromOpenBookings, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .option])
            .disabled(openBookingsCommandState?.canCreateTripFromSelection != true)

            Button(L10n.string(.menuAddBooking)) {
                NotificationCenter.default.post(name: .reisenAddBooking, object: nil)
            }
            .keyboardShortcut("n", modifiers: [.command, .shift])
            .disabled(!canPerformSingleTripActions)
            .menuDisabledOnlyHelp(
                isEnabled: canPerformSingleTripActions,
                disabledHelp: L10n.string(.tripSelectTrip)
            )

            // ⌘V bleibt System-Paste; der Paste-Import liegt auf ⌘⇧V.
            PasteImportActionControl(kind: pasteImportKind) {
                NotificationCenter.default.post(name: .reisenPasteBooking, object: nil)
            }
            .keyboardShortcut("v", modifiers: [.command, .shift])

            Button(L10n.string(.menuPasteBookingFromFile)) {
                NotificationCenter.default.post(name: .reisenPasteBookingFromFile, object: nil)
            }
            .disabled(pasteImportKind == .unavailable)

            Button(L10n.string(.menuAssignBookings)) {
                NotificationCenter.default.post(name: .reisenAssignBookings, object: nil)
            }
            .disabled(!canAssignBookings)
            .menuEnableHelp(
                isEnabled: canAssignBookings,
                enabledHelp: L10n.string(.tripAssignOpenHelp),
                disabledHelp: assignBookingsDisabledHelp
            )
        }

        CommandGroup(after: .appInfo) {
            Button(L10n.string(.menuSyncAllProviders)) {
                NotificationCenter.default.post(name: .reisenSyncAllProviders, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])
            .disabled(!canSyncAll)
            .menuEnableHelp(
                isEnabled: canSyncAll,
                enabledHelp: L10n.string(.actionSyncAllHelp),
                disabledHelp: L10n.string(.menuSyncAllUnavailableHelp)
            )

            Button(L10n.string(.menuSyncCurrentProvider)) {
                NotificationCenter.default.post(name: .reisenSyncCurrentProvider, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
            .disabled(!canSyncCurrent)
            .menuEnableHelp(
                isEnabled: canSyncCurrent,
                enabledHelp: L10n.string(.syncSyncBookingsHelp),
                disabledHelp: L10n.string(.syncUnavailableHelp)
            )
        }

        CommandGroup(after: .pasteboard) {
            Button(L10n.string(.menuEditTrip)) {
                NotificationCenter.default.post(name: .reisenEditSelectedTrip, object: nil)
            }
            .disabled(!canPerformSingleTripActions)
            .menuDisabledOnlyHelp(
                isEnabled: canPerformSingleTripActions,
                disabledHelp: L10n.string(.tripSelectTrip)
            )

            Button(BookingPortalOpenTitle.openInBrowser) {
                if let url = bookingPortalOpenCommandState?.url {
                    openURL(url)
                }
            }
            .disabled(!canOpenBookingPortal)
            .menuEnableHelp(
                isEnabled: canOpenBookingPortal,
                enabledHelp: BookingPortalOpenTitle.openInBrowserHelp,
                disabledHelp: L10n.string(.bookingDetailNoBrowserLink)
            )

            Button(BookingPortalCancelTitle.menu) {
                NotificationCenter.default.post(name: .reisenPresentBookingCancel, object: nil)
            }
            .disabled(!canCancelBookingPortal)
            .menuEnableHelp(
                isEnabled: canCancelBookingPortal,
                enabledHelp: BookingPortalCancelTitle.help,
                disabledHelp: L10n.string(.bookingDetailNoBrowserLink)
            )
        }
    }

    private var assignBookingsDisabledHelp: String {
        if canPerformSingleTripActions {
            return L10n.string(.tripNoOpenInRange)
        }
        return L10n.string(.tripSelectTrip)
    }
}
