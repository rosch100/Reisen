import Foundation

extension OpodoTripCancellationGraphQLParser {
    func parseISO8601(_ trimmed: String) -> Date? {
        let isoFrac = ISO8601DateFormatter()
        isoFrac.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = isoFrac.date(from: trimmed) {
            return date
        }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        return iso.date(from: trimmed)
    }

    /// JS Date oft ohne Zeitzone: 2026-08-01T22:00:00 — wie Opodo-UI als Wall-Clock UTC.
    func parseISOWallClockUTC(_ trimmed: String) -> Date? {
        guard trimmed.count >= 19,
              trimmed[trimmed.index(trimmed.startIndex, offsetBy: 10)] == "T" else {
            return nil
        }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        return f.date(from: String(trimmed.prefix(19)))
    }

    func parseISODayOnly(_ trimmed: String) -> Date? {
        let day = String(trimmed.prefix(10))
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: day)
    }
}
