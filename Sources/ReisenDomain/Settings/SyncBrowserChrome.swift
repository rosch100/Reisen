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

    /// Login-Guidance und Credential-CTAs liegen in einer Fläche oberhalb der WebView.
    public static func showsLoginChromeAboveWebView(isSessionReady: Bool) -> Bool {
        !isSessionReady
    }

    /// Untere Action-Bar: Sync/Collapse/Status nach Login — nicht parallel zu Login-Prompts.
    public static func showsBottomActionBar(isSessionReady: Bool) -> Bool {
        isSessionReady
    }
}
