import Foundation

public enum HotelStayDateLegacy {
    /// Stellt Legacy-„Hotel-Mitternacht“ wieder her, wenn Instant in Hotel-TZ Mitternacht war.
    public static func dateOnlyIfLegacyMidnight(
        _ date: Date,
        legacyHotelOffsetSeconds: Int?
    ) -> Date? {
        guard let offset = legacyHotelOffsetSeconds,
              let hotelTZ = TimeZone(secondsFromGMT: offset) else {
            return nil
        }
        var hotelCalendar = Calendar(identifier: .gregorian)
        hotelCalendar.timeZone = hotelTZ
        let hotelParts = hotelCalendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second],
            from: date
        )
        guard hotelParts.hour == 0,
              hotelParts.minute == 0,
              (hotelParts.second ?? 0) == 0,
              let year = hotelParts.year,
              let month = hotelParts.month,
              let day = hotelParts.day else {
            return nil
        }
        return HotelStayDate.dateOnly(year: year, month: month, day: day)
    }
}
