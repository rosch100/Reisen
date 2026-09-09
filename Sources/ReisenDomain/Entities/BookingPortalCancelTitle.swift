import Foundation

/// SSOT-Titel für Portal-Storno (Button/Menü/Help).
public enum BookingPortalCancelTitle {
    public static var button: String {
        L10n.string(.actionCancelInPortal)
    }

    public static var menu: String {
        L10n.string(.actionCancelInPortalMenu)
    }

    public static var help: String {
        L10n.string(.actionCancelInPortalHelp)
    }
}
