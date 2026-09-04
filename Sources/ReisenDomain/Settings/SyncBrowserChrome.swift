import Foundation

/// Regeln für eingebetteten Provider-Browser in der Sync-Chrome (macOS).
public enum SyncBrowserChrome: Sendable {
    /// Collapse/Expand nur sinnvoll, wenn Login nicht mehr der Hauptzweck ist.
    public static func showsCollapseControl(isSessionReady: Bool) -> Bool {
        isSessionReady
    }

    /// Bei Login-Bedarf bleibt der Browser gezwungen sichtbar.
    public static func isBrowserExpanded(isSessionReady: Bool, userExpanded: Bool) -> Bool {
        if isSessionReady {
            return userExpanded
        }
        return true
    }
}
