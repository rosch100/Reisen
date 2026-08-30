import SwiftUI
import AppKit
import ReisenDomain
import ReisenPasteImport
import ReisenSharedUI

struct ReisenCommands: Commands {
    @FocusedValue(\.openBookingsCommandState) private var openBookingsCommandState
    @FocusedValue(\.bookingPortalOpenCommandState) private var bookingPortalOpenCommandState
    @Environment(\.openURL) private var openURL

    /// Verfügbarkeit entscheidet über beide Einfüge-Einträge im Menü.
    ///
    /// Die Notification trägt die Modellstufe nicht mit; `PasteImportSession.start()`
    /// löst sie über `PasteImportResolvedModel.kind()` erneut auf — dieselbe Quelle, kein zweiter Pfad.
    private var pasteImportKind: PasteImportModelKind { PasteImportResolvedModel.kind() }

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
        }

        CommandGroup(after: .appInfo) {
            Button(L10n.string(.menuProviderSync)) {
                NotificationCenter.default.post(name: .reisenShowProviderSync, object: nil)
            }
            .keyboardShortcut("1", modifiers: [.command])

            Button(L10n.string(.menuSyncAllProviders)) {
                NotificationCenter.default.post(name: .reisenSyncAllProviders, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command, .shift])

            Button(L10n.string(.menuSyncCurrentProvider)) {
                NotificationCenter.default.post(name: .reisenSyncCurrentProvider, object: nil)
            }
            .keyboardShortcut("r", modifiers: [.command])
        }

        CommandGroup(after: .pasteboard) {
            Button(L10n.string(.menuEditTrip)) {
                NotificationCenter.default.post(name: .reisenEditSelectedTrip, object: nil)
            }

            Button(BookingPortalOpenTitle.openInBrowser) {
                if let url = bookingPortalOpenCommandState?.url {
                    openURL(url)
                }
            }
            .disabled(bookingPortalOpenCommandState?.canOpen != true)
            .help(
                bookingPortalOpenCommandState?.canOpen == true
                    ? BookingPortalOpenTitle.openInBrowserHelp
                    : L10n.string(.bookingDetailNoBrowserLink)
            )

            Button(BookingPortalCancelTitle.menu) {
                if let url = bookingPortalOpenCommandState?.cancellationURL {
                    openURL(url)
                }
            }
            .disabled(bookingPortalOpenCommandState?.canCancel != true)
            .help(
                bookingPortalOpenCommandState?.canCancel == true
                    ? BookingPortalCancelTitle.help
                    : L10n.string(.bookingDetailNoBrowserLink)
            )
        }
    }
}
