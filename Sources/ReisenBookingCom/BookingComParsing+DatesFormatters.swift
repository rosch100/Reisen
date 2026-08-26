import Foundation

extension BookingComParsing {
    static func dayOnlyUTC() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    static func germanDateTimeFormatter(offsetSeconds: Int) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }

    static func germanDateFormatter(offsetSeconds: Int) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy"
        return f
    }
}
