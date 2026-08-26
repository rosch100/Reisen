import Foundation

public enum CalendarTitleMode: String, CaseIterable, Codable, Equatable, Sendable {
    /// Create/select EventKit EKEvent + EKReminder calendars per trip title.
    case tripTitle = "tripTitle"
    /// Use the global names `calendarTitle` + `reminderCalendarTitle`.
    case fixed = "fixed"
}
