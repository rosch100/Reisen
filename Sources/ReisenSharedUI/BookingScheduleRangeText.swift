import Foundation
import ReisenData
import ReisenDomain

/// SSOT: Listen-/Overview-Datumszeile (flight-like inkl. Ortszeit-Uhrzeit).
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
        let start = booking.startAt.formatted(date: .abbreviated, time: .omitted)
        let end = booking.endAt.formatted(date: .abbreviated, time: .omitted)
        return "\(start) – \(end)"
    }
}
