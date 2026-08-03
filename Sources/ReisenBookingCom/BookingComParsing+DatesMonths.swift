import Foundation

extension BookingComParsing {
    static let months: [String: Int] = [
        // DE
        "januar": 1, "februar": 2, "märz": 3, "maerz": 3, "april": 4,
        "mai": 5, "juni": 6, "juli": 7, "august": 8,
        "september": 9, "oktober": 10, "november": 11, "dezember": 12,
        // EN (GraphQL/Session oft en-us)
        "january": 1, "february": 2, "march": 3, "may": 5, "june": 6,
        "july": 7, "october": 10, "december": 12,
        "jan": 1, "feb": 2, "mar": 3, "apr": 4, "jun": 6,
        "jul": 7, "aug": 8, "sep": 9, "sept": 9, "oct": 10, "nov": 11, "dec": 12,
    ]
}
