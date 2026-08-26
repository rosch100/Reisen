import Foundation

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
        return minutes(from: timeString)
    }

    static func subtitle(for which: Which, in row: AirbnbScheduledEventRow) -> String? {
        switch which {
        case .checkIn:
            return row.leadingSubtitle
        case .checkOut:
            return row.trailingSubtitle
        }
    }

    /// Expected format: "23:00" (German UI).
    static func minutes(from timeString: String) -> Int? {
        let parts = timeString.split(separator: ":")
        guard parts.count == 2, let hh = Int(parts[0]), let mm = Int(parts[1]) else { return nil }
        guard hh >= 0, hh < 24, mm >= 0, mm < 60 else { return nil }
        return hh * 60 + mm
    }
}
