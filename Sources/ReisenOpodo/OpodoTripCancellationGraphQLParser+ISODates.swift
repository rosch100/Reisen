import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    /// Parst ISO-Zeit inkl. Offset. HAR: `2026-08-01T22:00:00-00:00` → Anzeige 1.8. 22:00
    /// (nicht Geräte-Lokalzeit 2.8. 00:00 in CEST).
    func parseISODate(_ raw: String) -> (date: Date, offsetSeconds: Int?)? {
        guard let trimmed = NonEmpty.string(raw) else { return nil }

        // HAR/UI: `new Date(until)` — ISO und epoch-ms als String.
        if let millis = Int64(trimmed), trimmed.count >= 12,
           let date = dateFromEpochMillis(millis) {
            return (date, 0)
        }

        if let date = ISODateTime.parseInstant(trimmed) {
            return (date, ISODateTime.offsetSeconds(from: trimmed))
        }

        if let date = ISODateTime.parseWallClockUTC(trimmed) ?? HotelStayDate.parse(trimmed) {
            return (date, 0)
        }
        return nil
    }

    func dateFromEpochMillis(_ raw: Int64) -> Date? {
        Date(timeIntervalSince1970: TimeInterval(raw) / 1000)
    }
}
