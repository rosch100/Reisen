import Foundation

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

    /// Sichtbarkeit des Buchungs-Detailpanels (SceneStorage / UserDefaults).
    public static let tripDetailPanelVisible = "reisen_tripDetailPanelVisible"
    /// Persistierte Höhe des Buchungs-Detailpanels in Punkten.
    public static let tripDetailPanelHeight = "reisen_tripDetailPanelHeight"

    /// Persistierte Sidebar-Breite (Punkte); Resize über HIG-Divider.
    public static let sidebarColumnWidth = "reisen_sidebarColumnWidth"
    /// Persistierte Breite der mittleren Buchungsliste (Punkte).
    public static let bookingListColumnWidth = "reisen_bookingListColumnWidth"

    public static func providerEnabledKey(for providerID: ProviderID) -> String {
        "\(providerEnabledPrefix)\(providerID.rawValue)"
    }

    /// Persistierte Account-Auswahl: `"serverHost\\u{1F}username"`.
    public static func preferredKeychainAccountKey(for providerID: ProviderID) -> String {
        "\(preferredKeychainAccountPrefix)\(providerID.rawValue)"
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
        calendarTitle: String = "Reisen",
        reminderCalendarTitle: String = "Reisen",
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
        leadTimesDaysRaw
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { $0 > 0 }
    }
}

public enum CalendarTitleMode: String, CaseIterable, Codable, Equatable, Sendable {
    /// Create/select EventKit EKEvent + EKReminder calendars per trip title.
    case tripTitle = "tripTitle"
    /// Use the global names `calendarTitle` + `reminderCalendarTitle`.
    case fixed = "fixed"
}
