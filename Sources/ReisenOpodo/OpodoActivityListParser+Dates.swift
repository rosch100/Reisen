import Foundation

extension OpodoActivityListParser {
    func parseDate(_ raw: String) -> Date? {
        // Expected formats:
        // - yyyy-MM-dd
        // - dd.MM.yyyy
        let candidates = [raw.replacingOccurrences(of: #"T.*$"#, with: "", options: .regularExpression)]
        for candidate in candidates {
            if let d = parseISODate(candidate) { return d }
            if let d = parseGermanDate(candidate) { return d }
        }
        return nil
    }

    func parseISODate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: raw)
    }

    func parseGermanDate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy"
        return f.date(from: raw)
    }
}
