import Foundation

/// Welche Buchungen in Timeline und Offen-Liste erscheinen, und wann sie als abgelaufen gelten.
public enum BookingListInclusion {
    /// Start-Tag liegt nicht vor heute.
    public static func isUpcoming(
        startAt: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        !isCalendarDayBefore(startAt, now: now, calendar: calendar)
    }

    /// Nicht storniert, ab heute — oder manuell importiert (auch in der Vergangenheit).
    public static func appearsInList(
        startAt: Date,
        status: BookingStatus,
        provider: ProviderID,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        guard status != .cancelled else { return false }
        return isUpcoming(startAt: startAt, now: now, calendar: calendar)
            || provider == .manual
            || provider == .autoGap
    }

    /// Ende liegt kalendarisch vor heute.
    public static func isElapsed(
        endAt: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        isCalendarDayBefore(endAt, now: now, calendar: calendar)
    }

    private static func isCalendarDayBefore(
        _ date: Date,
        now: Date,
        calendar: Calendar
    ) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: now)
    }
}
