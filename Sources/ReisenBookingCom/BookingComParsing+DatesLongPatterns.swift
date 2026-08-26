import Foundation

extension BookingComParsing {
    /// DE: "11. August 2026" / "11. August 2026 23:59"
    static func parseLongDateDE(
        in text: String,
        defaultHour: Int,
        defaultMinute: Int,
        offsetSeconds: Int
    ) -> Date? {
        dateFromLongComponents(
            captures(
                #"(\d{1,2})\.\s*([A-Za-zÄÖÜäöüß]+)\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 0,
            monthIndex: 1,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        )
    }

    /// EN: "11 August 2026" / "11 August 2026 23:59"
    static func parseLongDateENDayMonth(
        in text: String,
        defaultHour: Int,
        defaultMinute: Int,
        offsetSeconds: Int
    ) -> Date? {
        dateFromLongComponents(
            captures(
                #"(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 0,
            monthIndex: 1,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        )
    }

    /// EN: "Aug 11, 2026" / "August 11, 2026"
    static func parseLongDateENMonthDay(
        in text: String,
        defaultHour: Int,
        defaultMinute: Int,
        offsetSeconds: Int
    ) -> Date? {
        dateFromLongComponents(
            captures(
                #"([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 1,
            monthIndex: 0,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        )
    }
}
