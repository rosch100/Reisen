import Foundation

/// Hotel-Wall-Clock-TZ: Booking-Offset → Deadline-Offset → GMT+0 (Opodo-/HotelStayDate-Konvention).
public enum HotelTimeZone {
    public static let wallClockUTC = TimeZone(secondsFromGMT: 0)!

    public static func resolve(
        bookingOffsetSeconds: Int?,
        deadlineOffsetSeconds: Int? = nil
    ) -> TimeZone {
        if let bookingOffsetSeconds,
           let tz = TimeZone(secondsFromGMT: bookingOffsetSeconds) {
            return tz
        }
        if let deadlineOffsetSeconds,
           let tz = TimeZone(secondsFromGMT: deadlineOffsetSeconds) {
            return tz
        }
        return wallClockUTC
    }

    public static func resolve(fromOffsetSeconds: Int?, toOffsetSeconds: Int?) -> TimeZone {
        resolve(bookingOffsetSeconds: fromOffsetSeconds ?? toOffsetSeconds)
    }
}
