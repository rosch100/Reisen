import Foundation

public enum AppSettingsUserDefaults {
    /// Snapshot of persisted settings for background side-effect rebuilds (CloudKit import, app activation).
    public static func load(_ defaults: UserDefaults = .standard) -> AppSettings {
        let titleModeRaw = defaults.string(forKey: AppSettingsKeys.calendarTitleMode)
            ?? CalendarTitleMode.tripTitle.rawValue
        return AppSettings(
            notificationEnabled: defaults.object(forKey: AppSettingsKeys.notificationEnabled) as? Bool ?? true,
            eventKitEnabled: defaults.bool(forKey: AppSettingsKeys.eventKitEnabled),
            calendarTitle: defaults.string(forKey: AppSettingsKeys.calendarTitle) ?? "Reisen",
            reminderCalendarTitle: defaults.string(forKey: AppSettingsKeys.reminderCalendarTitle) ?? "Reisen",
            leadTimesDaysRaw: defaults.string(forKey: AppSettingsKeys.leadTimesDays) ?? "7,3,1",
            calendarTitleMode: CalendarTitleMode(rawValue: titleModeRaw) ?? .tripTitle,
            calendarTripTimesEnabled: defaults.bool(forKey: AppSettingsKeys.calendarTripTimesEnabled),
            calendarFlightTimesEnabled: defaults.bool(forKey: AppSettingsKeys.calendarFlightTimesEnabled),
            calendarHotelStaysEnabled: defaults.bool(forKey: AppSettingsKeys.calendarHotelStaysEnabled),
            eventCalendarCreateIfMissing: defaults.bool(forKey: AppSettingsKeys.eventCalendarCreateIfMissing),
            reminderCalendarCreateIfMissing: defaults.bool(forKey: AppSettingsKeys.reminderCalendarCreateIfMissing)
        )
    }
}
