import Foundation
import ReisenDomain

/// Shared hotel-offset wall-clock formatting for cancellation deadlines.
enum CancellationDeadlineWallClock {
    /// `nil` when `hotelOffsetSeconds` is missing or not a valid GMT offset.
    static func string(for deadline: CancellationDeadline) -> String? {
        guard let tz = deadline.hotelOffsetSeconds.flatMap({ TimeZone(secondsFromGMT: $0) }) else {
            return nil
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE")
        formatter.timeZone = tz
        formatter.dateFormat = "d. MMM yyyy HH:mm"
        return formatter.string(from: deadline.deadlineAt)
    }
}
