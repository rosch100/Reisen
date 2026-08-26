import Foundation

public struct PreTravelHintLead: Equatable, Sendable {
    public let leadDays: Int
    public let fireAt: Date

    public init(leadDays: Int, fireAt: Date) {
        self.leadDays = leadDays
        self.fireAt = fireAt
    }
}

public enum PreTravelHintLeadKeys {
    public static func futureLeads(
        booking: Booking,
        leadTimes: [Int],
        now: Date,
        calendar: Calendar = .current
    ) -> [PreTravelHintLead] {
        guard booking.hasPreTravelImportantHints else { return [] }

        var result: [PreTravelHintLead] = []
        for leadDays in leadTimes {
            guard let fireAt = LeadTimesDays.fireAt(
                referenceDate: booking.startAt,
                leadDays: leadDays,
                calendar: calendar
            ) else { continue }
            guard LeadTimesDays.isFuture(fireAt, now: now) else { continue }
            result.append(PreTravelHintLead(leadDays: leadDays, fireAt: fireAt))
        }
        return result
    }
}
