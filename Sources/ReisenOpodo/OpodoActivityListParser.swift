import Foundation
import ReisenDomain

public struct OpodoActivityListParser: Sendable {
    public init() {}

    public func parseBookings(from html: String) throws -> [ProviderBookingDraft] {
        let pattern = #"href="(https?://[^"]+)"[^>]*data-start="([^"]+)"[^>]*data-end="([^"]+)""#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))

        var bookings: [ProviderBookingDraft] = []
        for match in matches {
            guard match.numberOfRanges == 4 else { continue }

            let url = try extractGroup(html: html, match: match, groupIndex: 1)
            let startRaw = try extractGroup(html: html, match: match, groupIndex: 2)
            let endRaw = try extractGroup(html: html, match: match, groupIndex: 3)

            guard let startAt = parseDate(startRaw),
                  let endAt = parseDate(endRaw) else {
                continue
            }

            let lower = url.lowercased()
            let bookingType: BookingType
            if lower.contains("hotel") || lower.contains("accommodation") || lower.contains("unterkunft") {
                bookingType = .hotel
            } else if lower.contains("flight") || lower.contains("flug") {
                bookingType = .flight
            } else {
                bookingType = .other
            }

            bookings.append(
                ProviderBookingDraft(
                    provider: .opodo,
                    bookingType: bookingType,
                    title: nil,
                    confirmationCode: nil,
                    externalUrl: url,
                    startAt: startAt,
                    endAt: endAt,
                    locationFrom: nil,
                    locationTo: nil,
                    status: .unknown,
                    deadlines: [],
                    rateDetails: nil
                )
            )
        }

        if bookings.isEmpty {
            throw OpodoActivityListParserError.noBookingsFound
        }

        return bookings
    }
}

public enum OpodoActivityListParserError: LocalizedError, Sendable {
    case noBookingsFound

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return "Keine Opodo-Buchungen im HTML gefunden."
        }
    }
}

private extension OpodoActivityListParser {
    func extractGroup(html: String, match: NSTextCheckingResult, groupIndex: Int) throws -> String {
        guard let range = Range(match.range(at: groupIndex), in: html) else {
            throw OpodoActivityListParserError.noBookingsFound
        }
        return String(html[range])
    }

    func parseDate(_ raw: String) -> Date? {
        // Expected formats:
        // - yyyy-MM-dd
        // - dd.MM.yyyy
        let candidates = [raw.replacingOccurrences(of: #"T.*$"#, with: "", options: .regularExpression)]
        for candidate in candidates {
            if let d = parseISODate(candidate) { return d }
            if let d = parseGermanDate(candidate) { return d }
        }
        return nil
    }

    func parseISODate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f.date(from: raw)
    }

    func parseGermanDate(_ raw: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "de_DE_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "dd.MM.yyyy"
        return f.date(from: raw)
    }
}

