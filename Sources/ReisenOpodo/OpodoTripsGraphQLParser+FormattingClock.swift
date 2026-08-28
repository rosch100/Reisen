import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    /// „14:00-23:59“ / „12:00“ → Minuten seit Mitternacht (erster Uhrzeit-Block).
    func parseClockMinutes(_ raw: String?) -> Int? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        guard let match = raw.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) else {
            return nil
        }
        return ClockTime.minutes(fromHHMM: String(raw[match]))
    }
}
