import SwiftUI
import ReisenDomain

private enum BookingPortalOpenChrome {
    static let systemImage = "arrow.up.right.square"
}

/// HIG-konformes Öffnen einer Buchungs-/Portal-URL (SwiftUI `Link` → `openURL`).
public struct BookingPortalOpenLink: View {
    let url: URL
    let title: String
    var helpText: String?

    public init(url: URL, title: String, helpText: String? = nil) {
        self.url = url
        self.title = title
        self.helpText = helpText
    }

    /// macOS: Browser-Titel + Help.
    public init(browserURL url: URL) {
        self.init(
            url: url,
            title: BookingPortalOpenTitle.openInBrowser,
            helpText: BookingPortalOpenTitle.openInBrowserHelp
        )
    }

    /// iOS: App- oder neutraler Open-Titel.
    public init(bookingURL url: URL, providerID: ProviderID, isNativeAppInstalled: Bool) {
        self.init(
            url: url,
            title: BookingPortalOpenTitle.openBooking(
                providerID: providerID,
                isNativeAppInstalled: isNativeAppInstalled
            )
        )
    }

    public var body: some View {
        Link(destination: url) {
            Label(title, systemImage: BookingPortalOpenChrome.systemImage)
        }
        .help(helpText ?? title)
    }
}

/// Kontextmenü-/Button-Aktion: URL über System `openURL` öffnen.
public struct BookingPortalOpenButton: View {
    let url: URL
    let title: String
    var helpText: String?

    @Environment(\.openURL) private var openURL

    public init(url: URL, title: String, helpText: String? = nil) {
        self.url = url
        self.title = title
        self.helpText = helpText
    }

    /// macOS: Browser-Titel + Help.
    public init(browserURL url: URL) {
        self.init(
            url: url,
            title: BookingPortalOpenTitle.openInBrowser,
            helpText: BookingPortalOpenTitle.openInBrowserHelp
        )
    }

    /// iOS: App- oder neutraler Open-Titel.
    public init(bookingURL url: URL, providerID: ProviderID, isNativeAppInstalled: Bool) {
        self.init(
            url: url,
            title: BookingPortalOpenTitle.openBooking(
                providerID: providerID,
                isNativeAppInstalled: isNativeAppInstalled
            )
        )
    }

    public var body: some View {
        Button {
            openURL(url)
        } label: {
            Label(title, systemImage: BookingPortalOpenChrome.systemImage)
        }
        .help(helpText ?? title)
    }
}
