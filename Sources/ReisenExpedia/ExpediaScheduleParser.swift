import Foundation
import ReisenDomain

enum ExpediaScheduleParser {
    struct Window: Equatable {
        let start: TemporalFact
        let end: TemporalFact
        /// Hotel wall-clock minutes; nil for non-hotel LOBs.
        let hotelCheckInMinutes: Int?
        let hotelCheckOutMinutes: Int?
    }

    /// Parses card secondaries like `von 7. Dez., 15:00 Uhr bis 8. Dez., 10:00 Uhr`.
    /// Hotel: calendar days via `HotelStayDate` + check-in/out minutes (no invented property TZ).
    /// Other LOBs: wall clocks in `Europe/Berlin` (expedia.de / de_DE portal locale).
    static func window(
        fromSecondaryTexts texts: [String],
        bookingType: BookingType
    ) -> Window? {
        for text in texts {
            if let pair = parseVonBis(text, bookingType: bookingType) {
                return pair
            }
        }
        return nil
    }

    static func reiseplanNumber(from texts: [String]) -> String? {
        for text in texts {
            guard let regex = try? NSRegularExpression(
                pattern: #"Reiseplan:\s*([0-9]+)"#,
                options: [.caseInsensitive]
            ) else { continue }
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let match = regex.firstMatch(in: text, options: [], range: range),
               let r = Range(match.range(at: 1), in: text)
            {
                return String(text[r])
            }
        }
        return nil
    }

    static func monthNumber(_ raw: String) -> Int? {
        let key = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ".", with: "")
            .lowercased()
        let map: [String: Int] = [
            "jan": 1, "januar": 1,
            "feb": 2, "februar": 2,
            "mär": 3, "mar": 3, "märz": 3, "maerz": 3,
            "apr": 4, "april": 4,
            "mai": 5,
            "jun": 6, "juni": 6,
            "jul": 7, "juli": 7,
            "aug": 8, "august": 8,
            "sep": 9, "sept": 9, "september": 9,
            "okt": 10, "oktober": 10, "oct": 10,
            "nov": 11, "november": 11,
            "dez": 12, "dezember": 12, "dec": 12,
        ]
        if let exact = map[key] { return exact }
        for (k, v) in map where key.hasPrefix(k) || k.hasPrefix(key) {
            return v
        }
        return nil
    }

    static func makeBerlinDate(
        year: Int,
        month: Int,
        day: Int,
        hour: Int,
        minute: Int
    ) -> Date? {
        guard let berlin = TimeZone(identifier: "Europe/Berlin") else { return nil }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        comps.hour = hour
        comps.minute = minute
        comps.second = 0
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = berlin
        return cal.date(from: comps)
    }

    private static func parseVonBis(
        _ text: String,
        bookingType: BookingType
    ) -> Window? {
        let pattern =
            #"von\s+(\d{1,2})\.\s*([A-Za-zäöüÄÖÜ.]+),?\s*(\d{1,2}):(\d{2})\s*Uhr\s+bis\s+(\d{1,2})\.\s*([A-Za-zäöüÄÖÜ.]+),?\s*(\d{1,2}):(\d{2})\s*Uhr"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range) else {
            return nil
        }
        func group(_ i: Int) -> String? {
            guard let r = Range(match.range(at: i), in: text) else { return nil }
            return String(text[r])
        }
        guard let d1 = group(1), let m1 = group(2), let h1 = group(3), let min1 = group(4),
              let d2 = group(5), let m2 = group(6), let h2 = group(7), let min2 = group(8),
              let month1 = monthNumber(m1), let month2 = monthNumber(m2),
              let day1 = Int(d1), let day2 = Int(d2),
              let hour1 = Int(h1), let minute1 = Int(min1),
              let hour2 = Int(h2), let minute2 = Int(min2)
        else { return nil }

        let year1 = inferYear(month: month1, day: day1)
        var year2 = inferYear(month: month2, day: day2, notBefore: year1)
        // Cross-year stays (e.g. 30. Dez. → 2. Jan.): end calendar before start → next year.
        if month2 < month1 || (month2 == month1 && day2 < day1), year2 <= year1 {
            year2 = year1 + 1
        }
        let checkIn = ClockTime.minutes(hours: hour1, minute: minute1)
        let checkOut = ClockTime.minutes(hours: hour2, minute: minute2)

        if bookingType == .hotel {
            let startDay = HotelStayDate.dateOnly(year: year1, month: month1, day: day1)
            let endDay = HotelStayDate.dateOnly(year: year2, month: month2, day: day2)
            return Window(
                start: .hotelDay(startDay, offsetSeconds: nil),
                end: .hotelDay(endDay, offsetSeconds: nil),
                hotelCheckInMinutes: checkIn,
                hotelCheckOutMinutes: checkOut
            )
        }

        let startDate = makeBerlinDate(
            year: year1, month: month1, day: day1, hour: hour1, minute: minute1
        )
        let endDate = makeBerlinDate(
            year: year2, month: month2, day: day2, hour: hour2, minute: minute2
        )
        guard let startDate, let endDate else { return nil }
        let pair = TemporalFact.pair(bookingType: bookingType, start: startDate, end: endDate)
        return Window(
            start: pair.start,
            end: pair.end,
            hotelCheckInMinutes: nil,
            hotelCheckOutMinutes: nil
        )
    }

    private static func inferYear(month: Int, day: Int, notBefore: Int? = nil) -> Int {
        let cal = Calendar(identifier: .gregorian)
        let now = Date()
        var year = cal.component(.year, from: now)
        if let notBefore, year < notBefore {
            year = notBefore
        }
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        guard let candidate = cal.date(from: comps) else { return year }
        if candidate.addingTimeInterval(180 * 24 * 3600) < now {
            year += 1
        }
        if let notBefore, year < notBefore {
            year = notBefore
        }
        return year
    }
}
