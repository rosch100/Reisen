import Foundation

extension OpodoCancellationDeadlineParser {
    func parseISODateFromSnippet(_ snippet: String) -> Date? {
        let isoFormatter = ISO8601DateFormatter()

        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) {
            if let date = isoFormatter.date(from: match) { return date }
        }

        isoFormatter.formatOptions = [.withInternetDateTime]
        if let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) {
            if let date = isoFormatter.date(from: match) { return date }
        }

        return nil
    }
}
