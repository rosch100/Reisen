import SwiftUI
import ReisenDomain
import ReisenData

/// SSOT-Kontextmenüeintrag „Buchungsnr. kopieren“ (nur wenn Code gesetzt).
public struct BookingCopyConfirmationMenuItems: View {
    let confirmationCode: String?

    @Environment(\.stringPasteboard) private var pasteboard

    public init(booking: SDBooking) {
        self.confirmationCode = booking.confirmationCode
    }

    public var body: some View {
        if let code = confirmationCode, !code.isEmpty {
            Button(L10n.string(.actionCopyConfirmation)) {
                CopyAccessibility.copy(code, using: pasteboard)
            }
        }
    }
}

/// Kontextmenüeintrag „Link kopieren“.
public struct CopyLinkMenuItem: View {
    let url: URL

    @Environment(\.stringPasteboard) private var pasteboard

    public init(url: URL) {
        self.url = url
    }

    public var body: some View {
        Button(L10n.string(.actionCopyLink)) {
            CopyAccessibility.copy(url.absoluteString, using: pasteboard)
        }
    }
}

/// Kontextmenü zum Kopieren von Gap-Info (Plain-Text-Zeilen; kein Tap-to-Copy auf der Zeile).
struct GapCopyMenuItems: View {
    let title: String
    let rangeText: String
    let kindLabel: String
    var priceText: String? = nil

    @Environment(\.stringPasteboard) private var pasteboard

    private var copyText: String {
        var lines = [title, rangeText, kindLabel]
        if let priceText, !priceText.isEmpty {
            lines.append(priceText)
        }
        return lines.joined(separator: "\n")
    }

    var body: some View {
        Button(L10n.string(.commonCopy)) {
            CopyAccessibility.copy(copyText, using: pasteboard)
        }
    }
}
