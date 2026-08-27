import Foundation

extension AppSettings {
    /// Ob Provider-Enrichment Stornofristen laden soll (Notifications, EventKit oder Kalenderzeiten).
    public var requiresDeadlineEnrichment: Bool {
        notificationEnabled
            || eventKitEnabled
            || calendarTripTimesEnabled
            || calendarFlightTimesEnabled
    }
}
