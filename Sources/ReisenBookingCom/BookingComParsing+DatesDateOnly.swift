import Foundation
import ReisenDomain

extension BookingComParsing {
    /// Hotel: nur der Kalendertag aus ISO (`yyyy-MM-dd…`), Uhrzeit/TZ verwerfen.
    struct DateOnlyStorage: Equatable, Sendable {
        var date: Date
        var offsetSeconds: Int
    }

    static func dateOnly(fromISO raw: String?) -> DateOnlyStorage? {
        guard let raw else { return nil }
        guard let date = HotelStayDate.parse(raw) else { return nil }
        return DateOnlyStorage(
            date: date,
            offsetSeconds: offsetSeconds(from: raw) ?? 0
        )
    }
}
