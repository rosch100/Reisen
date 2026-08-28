import Foundation

extension BookingComParsing {
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
