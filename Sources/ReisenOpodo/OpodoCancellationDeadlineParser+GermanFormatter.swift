import Foundation

extension OpodoCancellationDeadlineParser {
    func parseGermanLongDateWithDateFormatter(
        normalized: String,
        time: String?
    ) -> Date? {
        let normalizedWithoutMonthDot = removeTrailingMonthDot(normalized)
        let withDot = ensureLeadingDayDot(normalizedWithoutMonthDot)

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)

        if let time, !time.isEmpty {
            formatter.dateFormat = "d. MMMM yyyy HH:mm"
            if let date = formatter.date(from: "\(withDot) \(time)") { return date }

            formatter.dateFormat = "d. MMM yyyy HH:mm"
            if let date = formatter.date(from: "\(withDot) \(time)") { return date }
        }

        formatter.dateFormat = "d. MMMM yyyy"
        if let date = formatter.date(from: withDot) { return date }

        formatter.dateFormat = "d. MMM yyyy"
        return formatter.date(from: withDot)
    }
}
