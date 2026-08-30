import Foundation

/// SSOT-Titel für „Buchung öffnen“ (macOS Browser vs. iOS App/neutral).
public enum BookingPortalOpenTitle {
    /// macOS: immer externer Browser.
    public static var openInBrowser: String {
        L10n.string(.actionOpenInBrowser)
    }

    /// Kurztitel für die Action-Bar (HIG: knappe Button-Labels).
    public static var short: String {
        L10n.string(.actionOpenShort)
    }

    public static var openInBrowserHelp: String {
        L10n.string(.actionOpenInBrowserHelp)
    }

    /// iOS: Provider-App-Titel wenn erkannt, sonst neutrales „Buchung öffnen“.
    public static func openBooking(
        providerID: ProviderID,
        isNativeAppInstalled: Bool
    ) -> String {
        if isNativeAppInstalled {
            return L10n.format(.actionOpenInProviderApp, providerID.displayName)
        }
        return L10n.string(.actionOpenBooking)
    }
}
