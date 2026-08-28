import Foundation

/// ISO-8601 Datetime/Offset-Parsing für DateWindow (SSOT, vormals Booking.com-lokal).
public enum ISODateTime {
    public static func parse(_ raw: String?) -> Date? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        if let date = parseInstant(raw) { return date }
        return HotelStayDate.parse(raw)
    }

    /// Frac + Internet-DateTime + RFC-822-Offset (`+0800`). Kein Day-Only.
    public static func parseInstant(_ raw: String?) -> Date? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        if let date = isoFractionalSeconds().date(from: raw) { return date }
        if let date = isoBasic().date(from: raw) { return date }
        return rfc822Offset().date(from: raw)
    }

    /// Offset from trailing `Z` / `+HH:MM` / `-HHMM`. Ohne Offset-Marker: `nil`.
    public static func offsetSeconds(from raw: String?) -> Int? {
        guard let trimmed = NonEmpty.string(raw) else { return nil }
        if trimmed.uppercased().hasSuffix("Z") {
            return 0
        }
        let ns = trimmed as NSString
        guard let match = offsetRegex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)),
              match.numberOfRanges >= 4 else {
            return nil
        }
        let sign = ns.substring(with: match.range(at: 1)) == "-" ? -1 : 1
        guard let hours = Int(ns.substring(with: match.range(at: 2))),
              let minutes = Int(ns.substring(with: match.range(at: 3))) else {
            return nil
        }
        return sign * (hours * 3600 + minutes * 60)
    }

    /// Wanduhr als UTC-Instant + Offset (Normalizer zieht Offset ab).
    public struct WallClockStorage: Equatable, Sendable {
        public var wallClockAsUTC: Date
        public var offsetSeconds: Int?

        public init(wallClockAsUTC: Date, offsetSeconds: Int?) {
            self.wallClockAsUTC = wallClockAsUTC
            self.offsetSeconds = offsetSeconds
        }
    }

    public static func wallClockStorage(fromISO raw: String?) -> WallClockStorage? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        if let instant = parseInstant(raw) {
            let offset = offsetSeconds(from: raw)
            let wallClock = offset.map { instant.addingTimeInterval(TimeInterval($0)) } ?? instant
            return WallClockStorage(wallClockAsUTC: wallClock, offsetSeconds: offset)
        }
        if let wall = parseWallClockUTC(raw) {
            return WallClockStorage(wallClockAsUTC: wall, offsetSeconds: nil)
        }
        guard let date = HotelStayDate.parse(raw) else { return nil }
        return WallClockStorage(wallClockAsUTC: date, offsetSeconds: offsetSeconds(from: raw))
    }

    public struct DateOnlyStorage: Equatable, Sendable {
        public var date: Date
        public var offsetSeconds: Int?

        public init(date: Date, offsetSeconds: Int?) {
            self.date = date
            self.offsetSeconds = offsetSeconds
        }
    }

    public static func dateOnly(fromISO raw: String?) -> DateOnlyStorage? {
        guard let raw = NonEmpty.string(raw),
              let date = HotelStayDate.parse(raw) else { return nil }
        return DateOnlyStorage(
            date: date,
            offsetSeconds: offsetSeconds(from: raw)
        )
    }

    private static let offsetRegex: NSRegularExpression = {
        do {
            return try NSRegularExpression(pattern: #"([+-])(\d{2}):?(\d{2})$"#)
        } catch {
            preconditionFailure("ISODateTime-Offset-Regex ist ungültig: \(error)")
        }
    }()

    private static func isoFractionalSeconds() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter
    }

    private static func isoBasic() -> ISO8601DateFormatter {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        return formatter
    }

    /// Wall-Clock ohne Offset als UTC (`2026-08-01T22:00:00` / `2026-08-11 23:59:00`).
    /// Nicht in `parse`/`parseInstant` — Day-Only und Instant bleiben getrennt.
    public static func parseWallClockUTC(_ raw: String?) -> Date? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        var head = String(raw.prefix(19))
        guard head.count == 19 else { return nil }
        let separator = head.index(head.startIndex, offsetBy: 10)
        if head[separator] == " " {
            head.replaceSubrange(separator...separator, with: "T")
        }
        guard head[head.index(head.startIndex, offsetBy: 10)] == "T" else { return nil }
        return posixUTC(format: "yyyy-MM-dd'T'HH:mm:ss").date(from: head)
    }

    /// Check24 `cancelableUntilHotel`: `2026-08-12T21:59:59+0800`.
    private static func rfc822Offset() -> DateFormatter {
        posixUTC(format: "yyyy-MM-dd'T'HH:mm:ssZ")
    }

    private static func posixUTC(format: String) -> DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = HotelStayDate.timeZone
        formatter.dateFormat = format
        formatter.isLenient = false
        return formatter
    }
}
