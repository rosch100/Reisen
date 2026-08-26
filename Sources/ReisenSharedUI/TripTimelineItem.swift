import Foundation
import ReisenData
import ReisenDomain

/// Interleaved Timeline: Buchungen und Gaps, Buchung vor Gap bei gleichem Start.
public enum TripTimelineItem: Identifiable, Equatable {
    case booking(SDBooking)
    case gap(ComputedGap)

    public var id: String {
        switch self {
        case .booking(let booking):
            return booking.id.uuidString
        case .gap(let gap):
            return gap.timelineItemID
        }
    }

    public var startDate: Date {
        switch self {
        case .booking(let booking):
            return booking.startAt
        case .gap(let gap):
            return gap.gapStart
        }
    }

    public static func sorted(bookings: [SDBooking], gaps: [ComputedGap]) -> [TripTimelineItem] {
        let bookingItems = bookings.map { TripTimelineItem.booking($0) }
        let gapItems = gaps.map { TripTimelineItem.gap($0) }
        return (bookingItems + gapItems).sorted { lhs, rhs in
            if lhs.startDate == rhs.startDate {
                switch (lhs, rhs) {
                case (.booking, .gap): return true
                case (.gap, .booking): return false
                default: return lhs.id < rhs.id
                }
            }
            return lhs.startDate < rhs.startDate
        }
    }
}
