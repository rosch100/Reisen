import Foundation

extension BookingComParsing {
    /// „vor dem 11. August 2026“ / „before Aug 11, 2026“ → Vortag 23:59 Hotel-Offset.
    static func parseExclusiveGermanPolicyDate(in text: String, offsetSeconds: Int = 0) -> Date? {
        let tz = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        guard let dayStart = parseGermanLongDate(in: text, endOfDay: false, offsetSeconds: offsetSeconds) else {
            return nil
        }
        let lower = text.lowercased()
        if lower.contains("vor dem") || lower.contains("before") {
            return exclusivePolicyPreviousDayEnd(dayStart: dayStart, calendar: cal, timeZone: tz)
        }
        return parseGermanLongDate(in: text, endOfDay: true, offsetSeconds: offsetSeconds)
    }

    static func exclusivePolicyPreviousDayEnd(
        dayStart: Date,
        calendar: Calendar,
        timeZone: TimeZone
    ) -> Date? {
        guard let previousDay = calendar.date(byAdding: .day, value: -1, to: dayStart) else { return nil }
        var comps = calendar.dateComponents([.year, .month, .day], from: previousDay)
        comps.hour = 23
        comps.minute = 59
        comps.second = 0
        comps.timeZone = timeZone
        return calendar.date(from: comps)
    }
}
