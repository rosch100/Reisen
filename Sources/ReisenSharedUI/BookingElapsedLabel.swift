import SwiftUI
import ReisenData
import ReisenDomain

/// Caption, wenn das Buchungsende kalendarisch vor `now` liegt.
public enum BookingElapsedText {
    public static func string(
        for booking: SDBooking,
        now: Date,
        calendar: Calendar? = nil
    ) -> String? {
        let resolved = calendar ?? booking.listInclusionCalendar
        guard booking.isElapsed(now: now, calendar: resolved) else { return nil }
        return L10n.string(.bookingElapsed)
    }
}

/// Einträge: sofort `startDate`, danach jeder Kalendertagbeginn (DST-sicher).
public struct CalendarDayTimelineSchedule: TimelineSchedule {
    public var calendar: Calendar

    public init(calendar: Calendar = .current) {
        self.calendar = calendar
    }

    public func entries(
        from startDate: Date,
        mode: TimelineScheduleMode
    ) -> [Date] {
        let limit = mode == .lowFrequency ? 8 : 400
        var dates = [startDate]
        var dayStart = calendar.startOfDay(for: startDate)
        for _ in 1..<limit {
            guard let next = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
            dates.append(next)
            dayStart = next
        }
        return dates
    }
}

/// Caption für Buchungen, deren Ende vor heute liegt.
public struct BookingElapsedLabel: View {
    private let booking: SDBooking
    private let injectedNow: Date?
    private let calendar: Calendar

    public init(for booking: SDBooking, now: Date? = nil, calendar: Calendar? = nil) {
        self.booking = booking
        self.injectedNow = now
        self.calendar = calendar ?? booking.listInclusionCalendar
    }

    public var body: some View {
        if let injectedNow {
            caption(now: injectedNow)
        } else {
            TimelineView(CalendarDayTimelineSchedule(calendar: calendar)) { context in
                caption(now: context.date)
            }
        }
    }

    @ViewBuilder
    private func caption(now: Date) -> some View {
        if let text = BookingElapsedText.string(for: booking, now: now, calendar: calendar) {
            Text(text)
                .font(.caption2)
                .foregroundStyle(.orange)
        }
    }
}
