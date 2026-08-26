import Foundation

public enum GapTripWindow {
    public static func bounds(from bookings: [Booking]) -> (start: Date, end: Date)? {
        guard let first = bookings.min(by: { $0.startAt < $1.startAt }),
              let last = bookings.max(by: { $0.endAt < $1.endAt }) else {
            return nil
        }
        return (first.startAt, last.endAt)
    }
}
