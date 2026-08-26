import Foundation

public enum LeadTimesDays {
    public static func normalized(_ leadTimesDays: [Int]) -> [Int] {
        leadTimesDays.sorted().filter { $0 > 0 }
    }

    public static func requireNonEmpty(_ leadTimesDays: [Int]) throws -> [Int] {
        let leadTimes = normalized(leadTimesDays)
        guard !leadTimes.isEmpty else {
            throw RepositoryError.invalidState("Keine gültigen Vorlaufzeiten konfiguriert.")
        }
        return leadTimes
    }

    public static func fireAt(
        referenceDate: Date,
        leadDays: Int,
        calendar: Calendar = .current
    ) -> Date? {
        calendar.date(byAdding: .day, value: -leadDays, to: referenceDate)
    }

    public static func isFuture(_ fireAt: Date, now: Date) -> Bool {
        fireAt > now
    }
}
