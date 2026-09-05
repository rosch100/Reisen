import Foundation
import ReisenData
import ReisenDomain

/// SSOT: Listen-/Overview-Datumszeile (flight-like inkl. Ortszeit-Uhrzeit; Hotel/Activity Wall-Clock-SSOT).
public enum BookingScheduleRangeText {
    public static func make(for booking: SDBooking) -> String {
        if booking.bookingType.usesFlightLikeSchedule {
            let start = Formatting.formatOrtszeit(
                booking.startAt,
                dateFormat: "d.M. HH:mm",
                timeZone: booking.resolvedFlightDepartureTimeZone
            )
            let end = Formatting.formatOrtszeit(
                booking.endAt,
                dateFormat: "d.M. HH:mm",
                timeZone: booking.resolvedFlightArrivalTimeZone
            )
            return "\(start) – \(end)"
        }
        // Hotel/Activity/Car/Other: kein Geräte-`.formatted` — HotelStayDate / resolvedHotelTimeZone.
        if booking.bookingType == .hotel {
            let start = HotelStayDate.format(
                booking.startAt,
                dateFormat: "d.M.yyyy",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            let end = HotelStayDate.format(
                booking.endAt,
                dateFormat: "d.M.yyyy",
                legacyHotelOffsetSeconds: booking.hotelOffsetSeconds
            )
            return "\(start) – \(end)"
        }
        let tz = booking.resolvedHotelTimeZone
        let start = Formatting.formatOrtszeit(booking.startAt, dateFormat: "d.M.yyyy", timeZone: tz)
        let end = Formatting.formatOrtszeit(booking.endAt, dateFormat: "d.M.yyyy", timeZone: tz)
        return "\(start) – \(end)"
    }
}
