import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseISODateFromSnippet(_ snippet: String) -> Date? {
        guard let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) else {
            return nil
        }
        return ISODateTime.parseInstant(match)
    }
}
