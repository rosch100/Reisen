import Foundation
import ReisenDomain

extension BookingComActivityListParser {
    func draft(url: String, startAt: Date, endAt: Date) -> ProviderBookingDraft? {
        let lower = url.lowercased()
        let bookingType: BookingType
        if lower.contains("hotel") || lower.contains("accommodation") || lower.contains("stays") {
            bookingType = .hotel
        } else if lower.contains("flight") || lower.contains("flug") {
            bookingType = .flight
        } else {
            bookingType = .hotel
        }
        let times = TemporalFact.pair(bookingType: bookingType, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .booking,
                bookingType: bookingType,
                start: times.start,
                end: times.end,
                externalUrl: url
            )
        )
    }

    func group(_ html: String, _ match: NSTextCheckingResult, _ index: Int) -> String? {
        guard let range = Range(match.range(at: index), in: html) else { return nil }
        return String(html[range])
    }

    func parseDate(_ raw: String) -> Date? {
        let day = raw.replacingOccurrences(of: #"T.*$"#, with: "", options: .regularExpression)
        return ISODateTime.parse(day) ?? HotelStayDate.parseGerman(day)
    }
}
