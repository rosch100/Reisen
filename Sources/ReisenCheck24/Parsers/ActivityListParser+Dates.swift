import Foundation
import ReisenDomain

extension ActivityListParser {
    func parseCatalogDate(_ raw: String?, bookingType: BookingType) -> Date? {
        guard bookingType == .hotel else {
            return parseFlexibleDate(raw)
        }
        let parsed = raw.flatMap(HotelStayDate.parse) ?? parseFlexibleDate(raw)
        guard let parsed else { return nil }
        return HotelStayDate.calendarDay(fromParsed: parsed)
    }

    func parseFlexibleDate(_ raw: String?) -> Date? {
        guard let raw = NonEmpty.string(raw) else { return nil }
        if let date = ISODateTime.parseInstant(raw) { return date }
        if let date = ISODateTime.parseWallClockUTC(raw) { return date }
        return HotelStayDate.parse(raw) ?? parseHarGmtDate(raw)
    }

    private func parseHarGmtDate(_ s: String) -> Date? {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE MMM dd yyyy HH:mm:ss 'GMT'Z"
        return df.date(from: s)
    }
}
