import Foundation

extension OpodoCancellationDeadlineParser {
    func parseOpodoBisDateFromSnippet(_ snippet: String) -> Date? {
        let match = firstMatch(
            pattern: #"(?i)(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})(?:\s*\(\s*Bis\s+(\d{1,2}:\d{2})\s*\))?"#,
            in: snippet
        ) ?? nil

        guard let _ = match else { return nil }

        guard let datePart = firstMatch(
            pattern: #"(?i)(\d{1,2}\.?\s*\p{L}+\.?\s*\d{4})"#,
            in: snippet
        ) else { return nil }

        let timePart = firstMatch(
            pattern: #"(?i)\(\s*Bis\s+(\d{1,2}:\d{2})\s*\)"#,
            in: snippet
        )

        return parseGermanLongDate(datePart, time: timePart)
    }
}
