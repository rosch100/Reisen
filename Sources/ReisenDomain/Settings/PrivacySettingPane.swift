import Foundation

/// Datenschutz-Pane, das der Nutzer freigeben muss (Kalender, Erinnerungen, Mitteilungen).
public enum PrivacySettingPane: String, Sendable, Hashable, CaseIterable {
    case calendars
    case reminders
    case notifications

    public var openButtonTitle: String { L10n.string(.privacyOpenSettings) }

    /// Kurzname für Statuszeilen, wenn die App ohne diese Freigabe weiterläuft.
    public var restrictedCapabilityLabel: String {
        L10n.privacySettingPaneDisplay(self)
    }

    public var denialMessage: String {
        switch self {
        case .calendars:
            return L10n.format(.privacyDenialCalendars, Self.privacyRootPath)
        case .reminders:
            return L10n.format(.privacyDenialReminders, Self.privacyRootPath)
        case .notifications:
            return L10n.format(.privacyDenialNotifications, Self.notificationsPath)
        }
    }

    private static var settingsAppName: String {
        #if os(iOS)
        L10n.string(.settingsAppIos)
        #else
        L10n.string(.settingsAppMacos)
        #endif
    }

    private static var privacyRootPath: String {
        L10n.format(.settingsPathPrivacy, settingsAppName)
    }

    private static var notificationsPath: String {
        L10n.format(.settingsPathNotifications, settingsAppName)
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
