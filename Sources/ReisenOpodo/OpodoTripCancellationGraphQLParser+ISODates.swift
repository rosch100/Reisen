import Foundation

extension OpodoTripCancellationGraphQLParser {
    /// Parst ISO-Zeit inkl. Offset. HAR: `2026-08-01T22:00:00-00:00` → Anzeige 1.8. 22:00
    /// (nicht Geräte-Lokalzeit 2.8. 00:00 in CEST).
    func parseISODate(_ raw: String) -> (date: Date, offsetSeconds: Int)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        // HAR/UI: `new Date(until)` — ISO und epoch-ms als String.
        if let millis = Int64(trimmed), trimmed.count >= 12,
           let date = dateFromEpochMillis(millis) {
            return (date, 0)
        }

        if let date = parseISO8601(trimmed) {
            return (date, isoOffsetSeconds(in: trimmed) ?? 0)
        }

        if let date = parseISOWallClockUTC(trimmed) {
            return (date, 0)
        }

        if let date = parseISODayOnly(trimmed) {
            return (date, 0)
        }
        return nil
    }
}
