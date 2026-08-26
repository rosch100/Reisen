import Foundation

extension OpodoCancellationDeadlineParser {
    // SSOT: Mapping Monatstoken (mit/ohne Punkt) → Monat (1-12)
    static let monthByToken: [String: Int] = [
        "jan": 1, "januar": 1, "january": 1,
        "feb": 2, "februar": 2, "february": 2,
        "mär": 3, "maerz": 3, "märz": 3, "marz": 3, "mar": 3, "march": 3,
        "apr": 4, "april": 4,
        "may": 5,
        "mai": 5,
        "jun": 6, "juni": 6,
        "jul": 7, "juli": 7,
        "aug": 8, "august": 8,
        "sep": 9, "sept": 9, "september": 9,
        "okt": 10, "oktober": 10, "oct": 10, "october": 10,
        "nov": 11, "november": 11,
        "dez": 12, "dezember": 12, "dec": 12, "december": 12
    ]

    func parseGermanLongDate(_ datePart: String, time: String?) -> Date? {
        let normalized = normalizeGermanLongDatePart(datePart)
        let tokenized = tokenizeGermanLongDate(normalized)

        if tokenized.count >= 3 {
            if let parsed = parseGermanLongDateDayMonthYear(parts: tokenized, time: time) {
                return parsed
            }
            if let parsed = parseGermanLongDateMonthDayYear(parts: tokenized, time: time) {
                return parsed
            }
        }

        return parseGermanLongDateWithDateFormatter(normalized: normalized, time: time)
    }
}
