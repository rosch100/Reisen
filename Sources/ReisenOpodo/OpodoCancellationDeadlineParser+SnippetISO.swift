import Foundation
import ReisenDomain

extension OpodoCancellationDeadlineParser {
    func parseISODateFromSnippet(_ snippet: String) -> (date: Date, offsetSeconds: Int?)? {
        guard let match = firstMatch(
            pattern: #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ) else {
            return nil
        }
        guard let date = ISODateTime.parseInstant(match) else { return nil }
        return (date, ISODateTime.offsetSeconds(from: match))
    }
}
