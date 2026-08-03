import Foundation

extension OpodoCancellationDeadlineParser {
    func parseDeDateTimeFromSnippet(_ snippet: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy HH:mm"

        guard let match = firstMatch(
            pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})(?:\s*uhr)?"#,
            in: snippet
        ) else { return nil }

        return formatter.date(from: match)
    }

    func parseDeDateFromSnippet(_ snippet: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "dd.MM.yyyy"

        guard let match = firstMatch(pattern: #"(\d{2}\.\d{2}\.\d{4})"#, in: snippet) else { return nil }
        return formatter.date(from: match)
    }
}
