import Foundation
import ReisenDomain

extension BookingComParsing {
    /// Minutes since midnight from `THH:MM` in an ISO datetime.
    static func clockMinutes(from raw: String?) -> Int? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        let groups = captures(#"T(\d{2}):(\d{2})"#, in: raw)
        guard groups.count >= 2,
              let hours = Int(groups[0]),
              let minutes = Int(groups[1]) else { return nil }
        return ClockTime.minutes(hours: hours, minute: minutes)
    }
}
