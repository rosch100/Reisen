import Foundation

extension Notification.Name {
    /// Provider-Aktivierung geändert (Einstellungen, Sidebar, Selektion, Auto-Enable).
    public static let providerEnabledDidChange = Notification.Name("reisen_providerEnabledDidChange")
}

/// SSOT für Provider-Aktivierungsänderungen (Toggle, Selektion, Auto-Enable).
public enum ProviderEnabledChange {
    public static func notify() {
        NotificationCenter.default.post(name: .providerEnabledDidChange, object: nil)
    }
}

public struct AppSettingsKeys {
    public static let notificationEnabled = "reisen_notificationEnabled"
    public static let eventKitEnabled = "reisen_eventKitEnabled"
    public static let calendarTitle = "reisen_calendarTitle"
    public static let reminderCalendarTitle = "reisen_reminderCalendarTitle"
    public static let leadTimesDays = "reisen_leadTimesDays"

    public static let calendarTripTimesEnabled = "reisen_calendarTripTimesEnabled"
    public static let calendarFlightTimesEnabled = "reisen_calendarFlightTimesEnabled"
    public static let calendarHotelStaysEnabled = "reisen_calendarHotelStaysEnabled"

    /// Controls whether EventKit EKEvent + EKReminder calendars are global or created per trip title.
    public static let calendarTitleMode = "reisen_calendarTitleMode"

    public static let eventCalendarCreateIfMissing = "reisen_eventCalendarCreateIfMissing"
    public static let reminderCalendarCreateIfMissing = "reisen_reminderCalendarCreateIfMissing"

    public static let providerEnabledPrefix = "reisen_providerEnabled_"
    public static let preferredKeychainAccountPrefix = "reisen_preferredKeychainAccount_"

    /// Erststart-Setup: Weiter bestätigt (kein Auto-Sheet mehr).
    public static let providerSetupCompleted = "reisen_providerSetupCompleted_v1"
    /// Erststart-Setup: Später gewählt (kein Auto-Sheet mehr; Reopen möglich).
    public static let providerSetupDeferred = "reisen_providerSetupDeferred_v1"

    /// Passwort-Konten nach erfolgreichem Login automatisch in der App-Keychain speichern.
    public static let rememberLoginAutomatically = "reisen_rememberLoginAutomatically"

    /// Fehler automatisch als öffentliches GitHub-Issue senden (Opt-in, Default aus).
    public static let reportErrorsToGitHub = "reisen_reportErrorsToGitHub"

    /// Optionales GitHub-Konto zur Zuordnung in Issue-Texten (Attribution, nicht Meldeweg).
    public static let feedbackGitHubUsername = "reisen_feedbackGitHubUsername"

    /// Sichtbarkeit des Buchungs-Detailpanels (SceneStorage / UserDefaults).
    public static let tripDetailPanelVisible = "reisen_tripDetailPanelVisible"
    /// Persistierte Höhe des Buchungs-Detailpanels in Punkten.
    public static let tripDetailPanelHeight = "reisen_tripDetailPanelHeight"

    /// Persistierte Sidebar-Breite (Punkte); Resize über HIG-Divider.
    public static let sidebarColumnWidth = "reisen_sidebarColumnWidth"
    /// Persistierte Breite der mittleren Buchungsliste (Punkte).
    public static let bookingListColumnWidth = "reisen_bookingListColumnWidth"

    /// Bevorzugte Anzeige-/Umrechnungswährung (ISO 4217).
    public static let preferredCurrencyCode = "reisen_preferredCurrencyCode"
    /// Summen in die bevorzugte Währung umrechnen (Default aus).
    public static let convertAmountsToPreferredCurrency = "reisen_convertAmountsToPreferredCurrency"

    /// Gewähltes Homescreen-Icon (`AppIconStyle.rawValue`); Default `standard`.
    public static let appIconStyle = "reisen_appIconStyle"

    /// Nutzer erlaubt CloudKit-Mirroring (Opt-out: fehlender Key = an).
    public static let icloudSyncEnabled = "reisen_icloudSyncEnabled"

    public static func providerEnabledKey(for providerID: ProviderID) -> String {
        "\(providerEnabledPrefix)\(providerID.rawValue)"
    }

    /// Default: Provider opt-in (fehlender Key = aus). Upgrade: `ProviderEnabledDefaultsMigration`.
    public static func isProviderEnabled(
        _ providerID: ProviderID,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> Bool {
        let key = providerEnabledKey(for: providerID)
        guard defaults.object(forKey: key) != nil else { return false }
        return defaults.bool(forKey: key)
    }

    /// Persistierte Account-Auswahl: `"serverHost\\u{1F}username"`.
    public static func preferredKeychainAccountKey(for providerID: ProviderID) -> String {
        "\(preferredKeychainAccountPrefix)\(providerID.rawValue)"
    }

    /// Default: iCloud-Sync an (Opt-out; fehlender Key = erlaubt).
    public static func isICloudSyncEnabled(defaults: UserDefaults = AppSettingsDefaults.current) -> Bool {
        guard defaults.object(forKey: icloudSyncEnabled) != nil else { return true }
        return defaults.bool(forKey: icloudSyncEnabled)
    }

    public static func setICloudSyncEnabled(_ enabled: Bool, defaults: UserDefaults = AppSettingsDefaults.current) {
        defaults.set(enabled, forKey: icloudSyncEnabled)
    }

    /// Default: automatisches Speichern aus (Opt-in in den Einstellungen).
    public static func isRememberLoginAutomatically(defaults: UserDefaults = .standard) -> Bool {
        guard defaults.object(forKey: rememberLoginAutomatically) != nil else { return false }
        return defaults.bool(forKey: rememberLoginAutomatically)
    }

    /// Default: keine automatischen öffentlichen Fehler-Issues.
    public static func isReportErrorsToGitHub(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: reportErrorsToGitHub)
    }

    /// Normalisierter optionaler GitHub-Benutzername für Issue-Attribution.
    public static func optionalFeedbackGitHubUsername(defaults: UserDefaults = .standard) -> String? {
        GitHubUsername.optionalValid(defaults.string(forKey: feedbackGitHubUsername))
    }

    /// Default: Locale-Währung, sonst EUR.
    public static func preferredCurrency(
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> String {
        preferredCurrency(stored: nil, defaults: defaults, locale: locale)
    }

    /// AppStorage-/Formularwert; leer/`nil` → Defaults → Locale → EUR.
    public static func preferredCurrency(
        stored: String?,
        defaults: UserDefaults = .standard,
        locale: Locale = .current
    ) -> String {
        for raw in [stored, defaults.string(forKey: preferredCurrencyCode)].compactMap({ $0 }) {
            let normalized = CurrencyCode.normalize(raw)
            if !normalized.isEmpty {
                return normalized
            }
        }
        if let code = locale.currency?.identifier {
            let normalized = CurrencyCode.normalize(code)
            if !normalized.isEmpty {
                return normalized
            }
        }
        return CurrencyCode.fallback
    }

    public static func setPreferredCurrency(_ code: String, defaults: UserDefaults = .standard) {
        defaults.set(CurrencyCode.normalize(code), forKey: preferredCurrencyCode)
    }

    /// Default: Umrechnung aus.
    public static func convertsAmountsToPreferredCurrency(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: convertAmountsToPreferredCurrency)
    }

    public static func setConvertsAmountsToPreferredCurrency(_ enabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(enabled, forKey: convertAmountsToPreferredCurrency)
    }
}

public struct AppSettings: Equatable, Sendable {
    public var notificationEnabled: Bool
    public var eventKitEnabled: Bool
    public var calendarTitle: String
    public var reminderCalendarTitle: String
    public var leadTimesDaysRaw: String
    public var calendarTitleMode: CalendarTitleMode
    public var calendarTripTimesEnabled: Bool
    public var calendarFlightTimesEnabled: Bool
    public var calendarHotelStaysEnabled: Bool
    public var eventCalendarCreateIfMissing: Bool
    public var reminderCalendarCreateIfMissing: Bool

    public init(
        notificationEnabled: Bool = true,
        eventKitEnabled: Bool = false,
        calendarTitle: String = "Voyenna",
        reminderCalendarTitle: String = "Voyenna",
        leadTimesDaysRaw: String = "7,3,1",
        calendarTitleMode: CalendarTitleMode = .tripTitle,
        calendarTripTimesEnabled: Bool = false,
        calendarFlightTimesEnabled: Bool = false,
        calendarHotelStaysEnabled: Bool = false,
        eventCalendarCreateIfMissing: Bool = false,
        reminderCalendarCreateIfMissing: Bool = false
    ) {
        self.notificationEnabled = notificationEnabled
        self.eventKitEnabled = eventKitEnabled
        self.calendarTitle = calendarTitle
        self.reminderCalendarTitle = reminderCalendarTitle
        self.leadTimesDaysRaw = leadTimesDaysRaw
        self.calendarTitleMode = calendarTitleMode
        self.calendarTripTimesEnabled = calendarTripTimesEnabled
        self.calendarFlightTimesEnabled = calendarFlightTimesEnabled
        self.calendarHotelStaysEnabled = calendarHotelStaysEnabled
        self.eventCalendarCreateIfMissing = eventCalendarCreateIfMissing
        self.reminderCalendarCreateIfMissing = reminderCalendarCreateIfMissing
    }

    public var leadTimesDays: [Int] {
        LeadTimesDays.normalized(
            leadTimesDaysRaw
                .split(separator: ",")
                .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
        )
    }

    public static func fromUserDefaults(_ defaults: UserDefaults = .standard) -> AppSettings {
        AppSettingsUserDefaults.load(defaults)
    }
}
