import Foundation

extension BookingComParsing {
    static func dateFromLongComponents(
        _ groups: [String],
        dayIndex: Int,
        monthIndex: Int,
        yearIndex: Int,
        hourIndex: Int,
        minuteIndex: Int,
        defaultHour: Int,
        defaultMinute: Int,
        offsetSeconds: Int
    ) -> Date? {
        guard groups.count > max(dayIndex, monthIndex, yearIndex),
              let day = Int(groups[dayIndex]),
              let year = Int(groups[yearIndex]),
              let month = months[groups[monthIndex].lowercased()],
              day > 0, year > 0 else { return nil }

        let hour: Int
        let minute: Int
        if groups.count > minuteIndex,
           let h = Int(groups[hourIndex]),
           let m = Int(groups[minuteIndex]) {
            hour = h
            minute = m
        } else {
            hour = defaultHour
            minute = defaultMinute
        }

        let tz = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = tz
        return Calendar(identifier: .gregorian).date(from: components)
    }
}
