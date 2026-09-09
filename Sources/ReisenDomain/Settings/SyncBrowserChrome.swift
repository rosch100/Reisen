import Foundation

/// Anordnung der Login-Chrome-Spalten (Status vs. Credential-CTAs).
public enum SyncLoginChromeArrangement: Equatable, Sendable {
    case sideBySide
    case stacked
}

/// Vertikale Pinning-Semantik des Sync-Content-Stacks (Domain-SSOT; View mappt auf SwiftUI Alignment).
public enum SyncContentStackVerticalAlignment: Equatable, Sendable {
    case top
}

/// Regeln für Provider-Sync-Browser-Chrome (macOS + iOS): Placement und progressive Login-UI.
public enum SyncBrowserChrome: Sendable {
    /// Startbreite vor Geometry-Messung: stacked, damit Phone nicht mit Side-by-Side-CTAs kollabiert.
    public static let initialAvailableWidthAssumption: Double = 0

    /// Mindestbreite der Status/Guidance-Spalte (Side-by-Side).
    public static let statusColumnMinimumWidth: Double = 220

    /// Mindestbreite der Credential-CTAs (DE-Labels „Zugangsdaten ausfüllen“ + „Anmeldung merken…“).
    public static let credentialsColumnMinimumWidth: Double = 360

    /// Abstand zwischen Status- und Credentials-Spalte.
    public static let sideBySideSpacing: Double = 16

    /// Ab dieser Chrome-Breite liegen Status/Guidance und Credential-CTAs nebeneinander.
    public static let sideBySideMinimumWidth: Double =
        statusColumnMinimumWidth + credentialsColumnMinimumWidth + sideBySideSpacing

    /// Credentials behalten Intrinsic-Width (kein equal-flex-Kollaps / Zeichen-Wrap).
    public static let loginChromeCredentialsUseIntrinsicWidth = true

    /// Content-Stack immer top-pinnen. Bei collapsed Browser (kein flexibles WebView-Kind)
    /// zentriert SwiftUI sonst Session-Banner und Action-Bar vertikal in der Detailfläche.
    public static func contentStackVerticalAlignment(
        isBrowserExpanded _: Bool
    ) -> SyncContentStackVerticalAlignment {
        .top
    }

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

    /// SSOT für Adaptive Login-Chrome: gemessene Breite + Accessibility-Schrift (HIG).
    public static func loginChromeArrangement(
        availableWidth: Double,
        prefersStackedForAccessibilityText: Bool = false
    ) -> SyncLoginChromeArrangement {
        if prefersStackedForAccessibilityText {
            return .stacked
        }
        return prefersSideBySideLoginChrome(availableWidth: availableWidth) ? .sideBySide : .stacked
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

    /// System-Tastatur oder Form-Accessory belegt den unteren Bildschirmrand (Keyboard-Frame in Screen-Koordinaten).
    public static func isKeyboardChromeOccupyingBottom(
        endFrameMinY: Double,
        endFrameMaxY: Double,
        screenMinY: Double,
        screenMaxY: Double,
        minimumOverlap: Double = 1
    ) -> Bool {
        let overlap = max(0, min(endFrameMaxY, screenMaxY) - max(endFrameMinY, screenMinY))
        return overlap > minimumOverlap
    }

    /// Floating-TabBar ausblenden, solange Sync aktiv und Keyboard-Chrome den unteren Rand belegt.
    public static func hidesTabBarWhileKeyboardChromeVisible(
        isSyncTabSelected: Bool,
        keyboardChromeOccupiesBottom: Bool
    ) -> Bool {
        hidesTabBarForSyncBrowserChrome(
            isSyncTabSelected: isSyncTabSelected,
            needsLogin: false,
            keyboardChromeOccupiesBottom: keyboardChromeOccupiesBottom,
            webLoginInputFocused: false
        )
    }

    /// Floating-TabBar ausblenden bei Sync-Login, Keyboard-Chrome oder fokussiertem Web-Login-Feld.
    public static func hidesTabBarForSyncBrowserChrome(
        isSyncTabSelected: Bool,
        needsLogin: Bool,
        keyboardChromeOccupiesBottom: Bool,
        webLoginInputFocused: Bool
    ) -> Bool {
        guard isSyncTabSelected else { return false }
        return needsLogin || keyboardChromeOccupiesBottom || webLoginInputFocused
    }
}
