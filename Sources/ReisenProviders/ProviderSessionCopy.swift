import Foundation

/// Sync-/Session-Banner-Texte für Provider-WebView (iOS + macOS).
public enum ProviderSessionCopy: Sendable {
    public static let blockedNavigationHint =
        "Anmeldung bitte im Browserfenster fortsetzen – Sprung in die App wurde blockiert."

    public static let iosSessionReady =
        "WebView ist bereit — Buchungen können synchronisiert werden."
    public static let iosNeedsLogin =
        "Melde dich im WebView beim Provider an (inkl. 2FA falls nötig)."
    public static let iosInstalledAppHint =
        " Sync erfordert eine separate Anmeldung in der WebView – die installierte App reicht nicht."

    public static let macSessionReady = "Du kannst jetzt die Buchungen synchronisieren."
    public static let macNeedsLogin =
        "Melde dich im Browser unten beim Provider an (inkl. 2FA falls nötig)."

    public static func iosSubtitle(
        navigationWasBlocked: Bool,
        isSessionReady: Bool,
        isNativeAppInstalled: Bool
    ) -> String {
        subtitle(
            navigationWasBlocked: navigationWasBlocked,
            isSessionReady: isSessionReady,
            readyText: iosSessionReady,
            needsLoginText: iosNeedsLogin,
            installedAppSuffix: isNativeAppInstalled ? iosInstalledAppHint : nil
        )
    }

    public static func macSubtitle(navigationWasBlocked: Bool, isSessionReady: Bool) -> String {
        subtitle(
            navigationWasBlocked: navigationWasBlocked,
            isSessionReady: isSessionReady,
            readyText: macSessionReady,
            needsLoginText: macNeedsLogin,
            installedAppSuffix: nil
        )
    }

    private static func subtitle(
        navigationWasBlocked: Bool,
        isSessionReady: Bool,
        readyText: String,
        needsLoginText: String,
        installedAppSuffix: String?
    ) -> String {
        if navigationWasBlocked { return blockedNavigationHint }
        if isSessionReady { return readyText }
        if let installedAppSuffix { return needsLoginText + installedAppSuffix }
        return needsLoginText
    }
}
