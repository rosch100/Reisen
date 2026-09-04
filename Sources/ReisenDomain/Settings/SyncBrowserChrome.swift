import Foundation

/// Regeln für Provider-Sync-Browser-Chrome (macOS + iOS): Placement und progressive Login-UI.
public enum SyncBrowserChrome: Sendable {
    /// Ab dieser Chrome-Breite liegen Status/Guidance und Credential-CTAs nebeneinander.
    public static let sideBySideMinimumWidth: Double = 560

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

    /// Breite genug für Side-by-Side von Status und Anmelde-CTAs (macOS / iPad regular).
    public static func prefersSideBySideLoginChrome(availableWidth: Double) -> Bool {
        availableWidth >= sideBySideMinimumWidth
    }

    /// „Ausfüllen“ nur wenn mindestens ein Keychain-Konto da ist (leer → Speichern/Hilfe).
    public static func showsFillCredentialsControl(accountCount: Int) -> Bool {
        accountCount >= 1
    }

    public static func showsAccountPicker(accountCount: Int) -> Bool {
        accountCount > 1
    }

    public static func showsSelectedAccountLabel(accountCount: Int) -> Bool {
        accountCount == 1
    }

    /// Nach Login: „Anmeldung merken“ auch in der Sync-Action-Bar (Session-only / manuell).
    public static func showsRememberLoginInBottomBar(isSessionReady: Bool) -> Bool {
        isSessionReady
    }
}
