import Foundation
import ReisenDomain

enum AirbnbScheduledEventsMinutes {
    enum Which {
        case checkIn
        case checkOut
    }

    static func parse(
        rows: [AirbnbScheduledEventRow],
        rowID: String,
        which: Which
    ) -> Int? {
        guard let row = rows.first(where: { $0.id == rowID }) else { return nil }
        guard let timeString = subtitle(for: which, in: row) else { return nil }
        return ClockTime.minutes(fromHHMM: timeString)
    }

    static func subtitle(for which: Which, in row: AirbnbScheduledEventRow) -> String? {
        switch which {
        case .checkIn:
            return row.leadingSubtitle
        case .checkOut:
            return row.trailingSubtitle
        }
    }
}
