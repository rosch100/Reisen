import Foundation

extension BookingComParsing {
    /// e.g. "11. August 2026" → calendar day in der angegebenen Offset-Zeitzone (absolut).
    static func parseGermanLongDate(in text: String, endOfDay: Bool, offsetSeconds: Int = 0) -> Date? {
        parseGermanLongDateTime(
            in: text,
            defaultHour: endOfDay ? 23 : 0,
            defaultMinute: endOfDay ? 59 : 0,
            offsetSeconds: offsetSeconds
        )
    }

    /// e.g. "10. August 2026 23:59" (HAR Confirmation Fee-Schedule) in Hotel-Offset.
    static func parseGermanLongDateTime(
        in text: String,
        defaultHour: Int = 0,
        defaultMinute: Int = 0,
        offsetSeconds: Int = 0
    ) -> Date? {
        if let date = parseLongDateDE(in: text, defaultHour: defaultHour, defaultMinute: defaultMinute, offsetSeconds: offsetSeconds) {
            return date
        }
        if let date = parseLongDateENDayMonth(in: text, defaultHour: defaultHour, defaultMinute: defaultMinute, offsetSeconds: offsetSeconds) {
            return date
        }
        return parseLongDateENMonthDay(in: text, defaultHour: defaultHour, defaultMinute: defaultMinute, offsetSeconds: offsetSeconds)
    }
}
