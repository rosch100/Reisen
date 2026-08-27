import Foundation

/// Datenschutz-Pane, das der Nutzer freigeben muss (Kalender, Erinnerungen, Mitteilungen).
public enum PrivacySettingPane: String, Sendable, Hashable, CaseIterable {
    case calendars
    case reminders
    case notifications

    public var openButtonTitle: String { "Einstellungen öffnen" }

    /// Kurzname für Statuszeilen, wenn die App ohne diese Freigabe weiterläuft.
    public var restrictedCapabilityLabel: String {
        switch self {
        case .calendars: return "Kalender"
        case .reminders: return "Erinnerungen"
        case .notifications: return "Mitteilungen"
        }
    }

    public var denialMessage: String {
        switch self {
        case .calendars:
            return """
            Kalenderzugriff wurde verweigert.

            Bitte aktiviere unter „\(Self.privacyRootPath) → Kalender“ für „Reisen“ den Schalter.
            """
        case .reminders:
            return """
            Erinnerungen-Zugriff wurde verweigert.

            Bitte aktiviere unter „\(Self.privacyRootPath) → Erinnerungen“ für „Reisen“ den Schalter.
            """
        case .notifications:
            return """
            Benachrichtigungen wurden nicht autorisiert.

            Bitte aktiviere unter „\(Self.notificationsPath)“ die Mitteilungen für „Reisen“.
            """
        }
    }

    private static var settingsAppName: String {
        #if os(iOS)
        "Einstellungen"
        #else
        "Systemeinstellungen"
        #endif
    }

    private static var privacyRootPath: String {
        "\(settingsAppName) → Datenschutz & Sicherheit"
    }

    private static var notificationsPath: String {
        "\(settingsAppName) → Mitteilungen"
    }
}

/// Fehler, der eine konkrete Datenschutz-Freigabe braucht.
public protocol PrivacyAccessDenying {
    var privacySettingPane: PrivacySettingPane? { get }
}

public enum PrivacyAccessDenial {
    public static func pane(from error: Error) -> PrivacySettingPane? {
        (error as? any PrivacyAccessDenying)?.privacySettingPane
    }
}

/// Deep-Links in die Systemeinstellungen (macOS). iOS nutzt die App-eigene Einstellungsseite.
public enum PrivacySettingsURL {
    public static func macOSCandidates(
        for pane: PrivacySettingPane,
        bundleIdentifier: String? = nil
    ) -> [URL] {
        switch pane {
        case .calendars:
            return urls([
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Calendars",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars",
            ])
        case .reminders:
            return urls([
                "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Reminders",
                "x-apple.systempreferences:com.apple.preference.security?Privacy_Reminders",
            ])
        case .notifications:
            var candidates: [String] = []
            if let bundleIdentifier, !bundleIdentifier.isEmpty {
                candidates.append(
                    "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleIdentifier)"
                )
            }
            candidates.append("x-apple.systempreferences:com.apple.Notifications-Settings.extension")
            return urls(candidates)
        }
    }

    private static func urls(_ strings: [String]) -> [URL] {
        strings.compactMap(URL.init(string:))
    }
}
