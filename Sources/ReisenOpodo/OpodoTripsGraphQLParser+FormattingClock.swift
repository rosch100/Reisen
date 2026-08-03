import Foundation

extension OpodoTripsGraphQLParser {
    /// „14:00-23:59“ / „12:00“ → Minuten seit Mitternacht (erster Uhrzeit-Block).
    func parseClockMinutes(_ raw: String?) -> Int? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let match = raw.range(of: #"\d{1,2}:\d{2}"#, options: .regularExpression) else {
            return nil
        }
        let token = String(raw[match])
        let parts = token.split(separator: ":")
        guard parts.count == 2,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              (0...23).contains(hours),
              (0...59).contains(minutes) else {
            return nil
        }
        return hours * 60 + minutes
    }
}
