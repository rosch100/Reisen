import Foundation

extension BookingComParsing {
    static func parseGermanDateTime(_ raw: String, offsetSeconds: Int = 0) -> Date? {
        germanDateTimeFormatter(offsetSeconds: offsetSeconds).date(from: raw)
    }

    static func parseGermanDate(_ raw: String, offsetSeconds: Int = 0) -> Date? {
        germanDateFormatter(offsetSeconds: offsetSeconds).date(from: raw)
    }

    static func parseGermanDateEndOfDay(_ raw: String, offsetSeconds: Int = 0) -> Date? {
        guard let day = parseGermanDate(raw, offsetSeconds: offsetSeconds) else { return nil }
        return day.addingTimeInterval(23 * 3600 + 59 * 60)
    }
}
