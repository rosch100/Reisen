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

/// HIG-Action-Bar: Öffnen- und Storno-Portal als SwiftUI `Link` + Button-Stil.
public struct BookingPortalActionBar: View {
    let openURL: URL?
    let cancellationURL: URL?
    var status: BookingStatus
    var openTitle: String
    var openHelp: String?
    var openButtonStyle: BookingPortalOpenButtonStyle
    var showsCopyMenu: Bool
    var deadlines: [CancellationDeadline]
    var now: Date
    var hasSessionWebView: Bool
    var onPresentCancel: (BookingPortalCancelPresentation, URL) -> Void

    public enum BookingPortalOpenButtonStyle {
        case bordered
        case prominent
    }

    public init(
        openURL: URL?,
        cancellationURL: URL?,
        status: BookingStatus,
        openTitle: String,
        openHelp: String? = nil,
        openButtonStyle: BookingPortalOpenButtonStyle,
        showsCopyMenu: Bool = false,
        deadlines: [CancellationDeadline],
        now: Date = Date(),
        hasSessionWebView: Bool,
        onPresentCancel: @escaping (BookingPortalCancelPresentation, URL) -> Void
    ) {
        self.openURL = openURL
        self.cancellationURL = cancellationURL
        self.status = status
        self.openTitle = openTitle
        self.openHelp = openHelp
        self.openButtonStyle = openButtonStyle
        self.showsCopyMenu = showsCopyMenu
        self.deadlines = deadlines
        self.now = now
        self.hasSessionWebView = hasSessionWebView
        self.onPresentCancel = onPresentCancel
    }

    public static func isVisible(
        open: URL?,
        cancellation: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date,
        hasSessionWebView: Bool
    ) -> Bool {
        let shown = BookingPortalActions.visible(
            open: open,
            cancellation: cancellation,
            status: status,
            deadlines: deadlines,
            now: now,
            hasSessionWebView: hasSessionWebView
        )
        return shown.open != nil || shown.cancel != nil
    }

    public var body: some View {
        let shown = BookingPortalActions.visible(
            open: openURL,
            cancellation: cancellationURL,
            status: status,
            deadlines: deadlines,
            now: now,
            hasSessionWebView: hasSessionWebView
        )
        let bar = HStack(spacing: 8) {
            if let open = shown.open {
                Link(destination: open) {
                    Label(openTitle, systemImage: BookingPortalOpenChrome.systemImage)
                }
                .modifier(BookingPortalOpenStyle(openButtonStyle))
                .help(openHelp ?? openTitle)
            }
            if let cancel = shown.cancel {
                Button(role: BookingPortalCancelChrome.usesDestructiveRole ? .destructive : nil) {
                    let presentation = BookingPortalCancellation.presentation(
                        cancellation: cancel,
                        open: openURL,
                        status: status,
                        deadlines: deadlines,
                        now: now,
                        hasSessionWebView: hasSessionWebView
                    )
                    onPresentCancel(presentation, cancel)
                } label: {
                    Label(BookingPortalCancelTitle.button, systemImage: BookingPortalCancelChrome.systemImage)
                }
                .buttonStyle(.bordered)
                .help(BookingPortalCancelTitle.help)
            }
        }
        if showsCopyMenu {
            bar.contextMenu {
                if let url = shown.open { CopyLinkMenuItem(url: url) }
                if let url = shown.cancel {
                    CopyLinkMenuItem(
                        url: url,
                        title: L10n.string(.actionCopyCancellationLink)
                    )
                }
            }
        } else {
            bar
        }
    }
}

private struct BookingPortalOpenStyle: ViewModifier {
    var style: BookingPortalActionBar.BookingPortalOpenButtonStyle

    init(_ style: BookingPortalActionBar.BookingPortalOpenButtonStyle) {
        self.style = style
    }

    func body(content: Content) -> some View {
        switch style {
        case .prominent: content.buttonStyle(.borderedProminent)
        case .bordered: content.buttonStyle(.bordered)
        }
    }
}

/// Kontextmenü: Storno-Seite im Portal öffnen.
public struct BookingPortalCancelMenuButton: View {
    let url: URL
    let presentation: BookingPortalCancelPresentation
    var onPresentCancel: (BookingPortalCancelPresentation, URL) -> Void

    public init(
        url: URL,
        presentation: BookingPortalCancelPresentation,
        onPresentCancel: @escaping (BookingPortalCancelPresentation, URL) -> Void
    ) {
        self.url = url
        self.presentation = presentation
        self.onPresentCancel = onPresentCancel
    }

    public var body: some View {
        Button(role: BookingPortalCancelChrome.usesDestructiveRole ? .destructive : nil) {
            onPresentCancel(presentation, url)
        } label: {
            Label(BookingPortalCancelTitle.menu, systemImage: BookingPortalCancelChrome.systemImage)
        }
        .help(BookingPortalCancelTitle.help)
    }
}

/// Kontextmenü-Storno, nur wenn Presentation nicht hidden.
public struct BookingPortalCancelMenuItems: View {
    let cancellationURL: URL?
    let openURL: URL?
    var status: BookingStatus
    var deadlines: [CancellationDeadline]
    var now: Date
    var hasSessionWebView: Bool
    var onPresentCancel: (BookingPortalCancelPresentation, URL) -> Void

    public init(
        cancellationURL: URL?,
        openURL: URL?,
        status: BookingStatus,
        deadlines: [CancellationDeadline],
        now: Date = Date(),
        hasSessionWebView: Bool,
        onPresentCancel: @escaping (BookingPortalCancelPresentation, URL) -> Void
    ) {
        self.cancellationURL = cancellationURL
        self.openURL = openURL
        self.status = status
        self.deadlines = deadlines
        self.now = now
        self.hasSessionWebView = hasSessionWebView
        self.onPresentCancel = onPresentCancel
    }

    public var body: some View {
        let presentation = BookingPortalCancellation.presentation(
            cancellation: cancellationURL,
            open: openURL,
            status: status,
            deadlines: deadlines,
            now: now,
            hasSessionWebView: hasSessionWebView
        )
        if presentation != .hidden, let cancelURL = cancellationURL {
            BookingPortalCancelMenuButton(
                url: cancelURL,
                presentation: presentation,
                onPresentCancel: onPresentCancel
            )
        }
    }
}
