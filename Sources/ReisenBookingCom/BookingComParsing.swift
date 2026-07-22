import Foundation
import ReisenDomain

/// Shared parsing helpers for Booking.com HTML/JSON/GraphQL (SSOT).
enum BookingComParsing {
    static let secureBookingOrigin = "https://secure.booking.com"

    private static let months: [String: Int] = [
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

    /// First capture group of `pattern`, or nil.
    static func capture(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        captures(pattern, in: text, options: options).first
    }

    /// Capture groups 1…n (empty strings omitted only when range missing).
    static func captures(
        _ pattern: String,
        in text: String,
        options: NSRegularExpression.Options = []
    ) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return []
        }
        let ns = text as NSString
        let full = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: text, options: [], range: full) else { return [] }
        var groups: [String] = []
        for index in 1..<match.numberOfRanges {
            let range = match.range(at: index)
            guard range.location != NSNotFound else { continue }
            groups.append(ns.substring(with: range))
        }
        return groups
    }

    static func normalizeEuroEntities(_ text: String) -> String {
        text
            .replacingOccurrences(of: "&euro;", with: "€", options: [.caseInsensitive])
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "\u{00a0}", with: " ")
    }

    /// ISO-8601 with/without fractional seconds; falls back to `yyyy-MM-dd`.
    static func parseISODateTime(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: raw) { return date }

        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        if let date = basic.date(from: raw) { return date }

        return dayOnlyUTC().date(from: String(raw.prefix(10)))
    }

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

    /// e.g. "11. August 2026" → calendar day in der angegebenen Offset-Zeitzone (absolut).
    static func parseGermanLongDate(in text: String, endOfDay: Bool, offsetSeconds: Int = 0) -> Date? {
        parseGermanLongDateTime(
            in: text,
            defaultHour: endOfDay ? 23 : 0,
            defaultMinute: endOfDay ? 59 : 0,
            offsetSeconds: offsetSeconds
        )
    }

    /// e.g. "10. August 2026 23:59" (HAR Confirmation Fee-Schedule) in Hotel-Offset.
    static func parseGermanLongDateTime(
        in text: String,
        defaultHour: Int = 0,
        defaultMinute: Int = 0,
        offsetSeconds: Int = 0
    ) -> Date? {
        if let date = dateFromLongComponents(
            captures(
                #"(\d{1,2})\.\s*([A-Za-zÄÖÜäöüß]+)\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 0,
            monthIndex: 1,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        ) {
            return date
        }
        // EN: "11 August 2026" / "11 August 2026 23:59"
        if let date = dateFromLongComponents(
            captures(
                #"(\d{1,2})\s+([A-Za-z]+)\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 0,
            monthIndex: 1,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        ) {
            return date
        }
        // EN: "Aug 11, 2026" / "August 11, 2026"
        return dateFromLongComponents(
            captures(
                #"([A-Za-z]+)\s+(\d{1,2}),?\s+(\d{4})(?:\s+(\d{2}):(\d{2}))?"#,
                in: text
            ),
            dayIndex: 1,
            monthIndex: 0,
            yearIndex: 2,
            hourIndex: 3,
            minuteIndex: 4,
            defaultHour: defaultHour,
            defaultMinute: defaultMinute,
            offsetSeconds: offsetSeconds
        )
    }

    /// „vor dem 11. August 2026“ / „before Aug 11, 2026“ → Vortag 23:59 Hotel-Offset.
    static func parseExclusiveGermanPolicyDate(in text: String, offsetSeconds: Int = 0) -> Date? {
        let tz = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)!
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        guard let dayStart = parseGermanLongDate(in: text, endOfDay: false, offsetSeconds: offsetSeconds) else {
            return nil
        }
        let lower = text.lowercased()
        if lower.contains("vor dem") || lower.contains("before") {
            guard let previousDay = cal.date(byAdding: .day, value: -1, to: dayStart) else { return nil }
            var comps = cal.dateComponents([.year, .month, .day], from: previousDay)
            comps.hour = 23
            comps.minute = 59
            comps.second = 0
            comps.timeZone = tz
            return cal.date(from: comps)
        }
        return parseGermanLongDate(in: text, endOfDay: true, offsetSeconds: offsetSeconds)
    }

    private static func dateFromLongComponents(
        _ groups: [String],
        dayIndex: Int,
        monthIndex: Int,
        yearIndex: Int,
        hourIndex: Int,
        minuteIndex: Int,
        defaultHour: Int,
        defaultMinute: Int,
        offsetSeconds: Int
    ) -> Date? {
        guard groups.count > max(dayIndex, monthIndex, yearIndex),
              let day = Int(groups[dayIndex]),
              let year = Int(groups[yearIndex]),
              let month = months[groups[monthIndex].lowercased()],
              day > 0, year > 0 else { return nil }

        let hour: Int
        let minute: Int
        if groups.count > minuteIndex,
           let h = Int(groups[hourIndex]),
           let m = Int(groups[minuteIndex]) {
            hour = h
            minute = m
        } else {
            hour = defaultHour
            minute = defaultMinute
        }

        let tz = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)!
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = 0
        components.timeZone = tz
        return Calendar(identifier: .gregorian).date(from: components)
    }

    /// Offset from trailing `+HH:MM` / `-HHMM` in an ISO datetime string.
    static func offsetSeconds(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let groups = captures(#"([+-])(\d{2}):?(\d{2})$"#, in: raw)
        guard groups.count >= 3,
              let hours = Int(groups[1]),
              let minutes = Int(groups[2]) else { return nil }
        let sign = groups[0] == "-" ? -1 : 1
        return sign * (hours * 3600 + minutes * 60)
    }

    /// Check24-kompatibel: Wanduhrzeit als UTC-Instant + Offset (Normalizer zieht Offset ab).
    struct WallClockStorage: Equatable, Sendable {
        var wallClockAsUTC: Date
        var offsetSeconds: Int
    }

    static func wallClockStorage(fromISO raw: String?) -> WallClockStorage? {
        guard let absolute = parseISODateTime(raw) else { return nil }
        let offset = offsetSeconds(from: raw) ?? 0
        return WallClockStorage(
            wallClockAsUTC: absolute.addingTimeInterval(TimeInterval(offset)),
            offsetSeconds: offset
        )
    }

    /// Hotel: nur der Kalendertag aus ISO (`yyyy-MM-dd…`), Uhrzeit/TZ verwerfen.
    struct DateOnlyStorage: Equatable, Sendable {
        var date: Date
        var offsetSeconds: Int
    }

    static func dateOnly(fromISO raw: String?) -> DateOnlyStorage? {
        guard let raw else { return nil }
        guard let date = HotelStayDate.parse(raw) else { return nil }
        return DateOnlyStorage(
            date: date,
            offsetSeconds: offsetSeconds(from: raw) ?? 0
        )
    }

    /// Minutes since midnight from `THH:MM` in an ISO datetime.
    static func clockMinutes(from raw: String?) -> Int? {
        guard let raw else { return nil }
        let groups = captures(#"T(\d{2}):(\d{2})"#, in: raw)
        guard groups.count >= 2,
              let hours = Int(groups[0]),
              let minutes = Int(groups[1]) else { return nil }
        return hours * 60 + minutes
    }

    static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    static func absoluteBookingURL(_ raw: String?) -> String? {
        guard let raw, !raw.isEmpty else { return nil }
        if raw.hasPrefix("http://") || raw.hasPrefix("https://") { return raw }
        if raw.hasPrefix("/") { return secureBookingOrigin + raw }
        return secureBookingOrigin + "/" + raw
    }

    /// GraphQL liefert z. B. `confirmation.en-us.html` / `confirmation.de.html`.
    /// Fee-Schedule-SSOT im HAR: `confirmation.html` mit `lang=de` (deutsche bis/ab-Zeilen).
    static func normalizedHotelConfirmationURL(_ raw: String?) -> String? {
        guard var url = absoluteBookingURL(raw) else { return nil }
        if let regex = try? NSRegularExpression(
            pattern: #"confirmation(?:\.[A-Za-z]{2}(?:-[A-Za-z]{2})?)?\.html"#,
            options: [.caseInsensitive]
        ) {
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            url = regex.stringByReplacingMatches(
                in: url,
                options: [],
                range: range,
                withTemplate: "confirmation.html"
            )
        }
        guard url.range(of: "confirmation.html", options: .caseInsensitive) != nil else {
            return url
        }
        if let langRegex = try? NSRegularExpression(pattern: #"lang=[^;&]+"#, options: [.caseInsensitive]) {
            let range = NSRange(url.startIndex..<url.endIndex, in: url)
            if langRegex.firstMatch(in: url, options: [], range: range) != nil {
                url = langRegex.stringByReplacingMatches(
                    in: url,
                    options: [],
                    range: range,
                    withTemplate: "lang=de"
                )
            } else {
                url += url.contains("?") ? ";lang=de" : "?lang=de"
            }
        }
        return url
    }

    static func dedupeByExternalURL(_ bookings: [ProviderBookingDraft]) -> [ProviderBookingDraft] {
        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        return Array(byURL.values).sorted { $0.startAt < $1.startAt }
    }

    /// Trip-IDs from My Trips SSR/HTML (`trip_id=`). HAR: present even when empty-state marketing copy is in the DOM.
    static func tripIDsFromMyTripsHTML(_ html: String) -> [String] {
        guard let regex = try? NSRegularExpression(
            pattern: #"trip_id=(\d{6,})"#,
            options: [.caseInsensitive]
        ) else { return [] }
        let ns = html as NSString
        let matches = regex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var ordered: [String] = []
        var seen = Set<String>()
        for match in matches {
            guard match.numberOfRanges >= 2 else { continue }
            let id = ns.substring(with: match.range(at: 1))
            guard !seen.contains(id) else { continue }
            seen.insert(id)
            ordered.append(id)
        }
        return ordered
    }

    private static func dayOnlyUTC() -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }

    private static func germanDateTimeFormatter(offsetSeconds: Int) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy HH:mm"
        return f
    }

    private static func germanDateFormatter(offsetSeconds: Int) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE")
        f.timeZone = TimeZone(secondsFromGMT: offsetSeconds) ?? TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy"
        return f
    }
}
