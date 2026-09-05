import SwiftUI
import ReisenDomain
import ReisenData

/// SSOT-Kontextmenüeintrag „Buchungsnummer kopieren“ (nur wenn Code gesetzt).
public struct BookingCopyConfirmationMenuItems: View {
    let confirmationCode: String?

    public init(booking: SDBooking) {
        self.confirmationCode = booking.confirmationCode
    }

    public var body: some View {
        if let code = confirmationCode, !code.isEmpty {
            PasteboardCopyMenuButton(title: L10n.string(.actionCopyConfirmation), text: code)
        }
    }
}

/// Kontextmenüeintrag „Link kopieren“.
public struct CopyLinkMenuItem: View {
    let url: URL
    let title: String

    public init(url: URL, title: String = L10n.string(.actionCopyLink)) {
        self.url = url
        self.title = title
    }

    public var body: some View {
        PasteboardCopyMenuButton(title: title, text: url.absoluteString)
    }
}

/// Kontextmenü zum Kopieren von Gap-Info (Plain-Text-Zeilen; kein Tap-to-Copy auf der Zeile).
struct GapCopyMenuItems: View {
    let title: String
    let rangeText: String
    let kindLabel: String
    var priceText: String? = nil

    private var copyText: String {
        ([title, rangeText, kindLabel] + [priceText].compactMap { $0 })
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }

    var body: some View {
        PasteboardCopyMenuButton(title: L10n.string(.commonCopy), text: copyText)
    }
}

/// Ein Kontextmenü-Button, der Plain-Text über `CopyAccessibility` schreibt.
private struct PasteboardCopyMenuButton: View {
    let title: String
    let text: String

    @Environment(\.stringPasteboard) private var pasteboard

    var body: some View {
        Button(title) {
            CopyAccessibility.copy(text, using: pasteboard)
        }
        .disabled(text.isEmpty)
    }
}
