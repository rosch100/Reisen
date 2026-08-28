import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseDeDateTimeFromSnippet(_ snippet: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.timeZone = HotelStayDate.timeZone
        formatter.dateFormat = "dd.MM.yyyy HH:mm"
        formatter.isLenient = false

        guard let match = firstMatch(
            pattern: #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})(?:\s*uhr)?"#,
            in: snippet
        ) else { return nil }

        return formatter.date(from: match)
    }

    func parseDeDateFromSnippet(_ snippet: String) -> Date? {
        guard let match = firstMatch(pattern: #"(\d{2}\.\d{2}\.\d{4})"#, in: snippet) else { return nil }
        return HotelStayDate.parseGerman(match)
    }
}
