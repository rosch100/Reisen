import Foundation

extension ActivityListParser {
    /// Vergangene (`ended`) und stornierte Buchungen aus; Start muss ab heute liegen.
    func isFutureRelevantBooking(statusKey: String, startAt: Date, now: Date) -> Bool {
        switch statusKey {
        case "cancelled", "canceled", "terminated", "ended":
            return false
        default:
            break
        }
        let startOfToday = Calendar.current.startOfDay(for: now)
        return startAt >= startOfToday
    }
}
