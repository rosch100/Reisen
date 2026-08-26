import Foundation

extension OpodoCancellationDeadlineParser {
    func parseGermanLongDateDayMonthYear(
        parts: [Substring],
        time: String?
    ) -> Date? {
        guard parts.count >= 3 else { return nil }
        let dayToken = String(parts[0]).replacingOccurrences(of: ".", with: "")
        let monthToken = String(parts[1]).lowercased().replacingOccurrences(of: ".", with: "")
        let yearToken = String(parts[2]).filter(\.isNumber)

        guard let day = Int(dayToken), let year = Int(yearToken), let month = Self.monthByToken[monthToken] else {
            return nil
        }

        return buildGermanLongDate(day: day, month: month, year: year, time: time)
    }

    func parseGermanLongDateMonthDayYear(
        parts: [Substring],
        time: String?
    ) -> Date? {
        guard parts.count >= 3 else { return nil }
        let monthToken = String(parts[0]).lowercased().replacingOccurrences(of: ".", with: "")
        let dayToken = String(parts[1]).replacingOccurrences(of: ".", with: "")
        let yearToken = String(parts[2]).filter(\.isNumber)

        guard let day = Int(dayToken), let year = Int(yearToken), let month = Self.monthByToken[monthToken] else {
            return nil
        }

        return buildGermanLongDate(day: day, month: month, year: year, time: time)
    }

    func buildGermanLongDate(
        day: Int,
        month: Int,
        year: Int,
        time: String?
    ) -> Date? {
        let calendar = Calendar(identifier: .gregorian)
        var components = DateComponents(
            calendar: calendar,
            timeZone: TimeZone(secondsFromGMT: 0),
            year: year,
            month: month,
            day: day
        )

        guard let time, !time.isEmpty else {
            return calendar.date(from: components)
        }

        let timeParts = time
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":")

        if timeParts.count == 2,
           let hour = Int(timeParts[0]),
           let minute = Int(timeParts[1]) {
            components.hour = hour
            components.minute = minute
        }

        return calendar.date(from: components)
    }
}
