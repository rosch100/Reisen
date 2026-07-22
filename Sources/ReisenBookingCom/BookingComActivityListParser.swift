import Foundation
import ReisenDomain

public struct BookingComActivityListParser: Sendable {
    public init() {}

    public func parseBookings(from html: String) throws -> [ProviderBookingDraft] {
        var bookings: [ProviderBookingDraft] = []
        bookings.append(contentsOf: parseDataAttributeCards(from: html))
        if bookings.isEmpty {
            bookings.append(contentsOf: parseJSONLDOrEmbeddedReservations(from: html))
        }
        if bookings.isEmpty {
            bookings.append(contentsOf: parseMyTripsLinks(from: html))
        }

        // Deduplicate by external URL.
        var byURL: [String: ProviderBookingDraft] = [:]
        for booking in bookings {
            guard let url = booking.externalUrl else { continue }
            byURL[url] = booking
        }
        let unique = Array(byURL.values).sorted { $0.startAt < $1.startAt }

        if unique.isEmpty {
            throw BookingComActivityListParserError.noBookingsFound
        }
        return unique
    }
}

public enum BookingComActivityListParserError: LocalizedError, Sendable {
    case noBookingsFound

    public var errorDescription: String? {
        switch self {
        case .noBookingsFound:
            return "Keine Booking.com-Buchungen im HTML gefunden."
        }
    }
}

private extension BookingComActivityListParser {
    func parseDataAttributeCards(from html: String) -> [ProviderBookingDraft] {
        let pattern = #"href="(https?://[^"]+)"[^>]*data-start="([^"]+)"[^>]*data-end="([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return [] }
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        var bookings: [ProviderBookingDraft] = []
        for match in matches {
            guard match.numberOfRanges == 4,
                  let url = group(html, match, 1),
                  let startRaw = group(html, match, 2),
                  let endRaw = group(html, match, 3),
                  let startAt = parseDate(startRaw),
                  let endAt = parseDate(endRaw) else { continue }
            bookings.append(draft(url: url, startAt: startAt, endAt: endAt))
        }
        return bookings
    }

    /// Embedded reservation-like JSON often present in SSR My Trips pages.
    func parseJSONLDOrEmbeddedReservations(from html: String) -> [ProviderBookingDraft] {
        let pattern = #""(?:booking_url|bookUrl|confirmation_url|url)"\s*:\s*"(https?://[^"]+booking\.com[^"]+)"[\s\S]{0,800}?"(?:checkin|check_in|startDate|arrival)"\s*:\s*"([^"]+)"[\s\S]{0,400}?"(?:checkout|check_out|endDate|departure)"\s*:\s*"([^"]+)""#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return [] }
        let matches = regex.matches(in: html, options: [], range: NSRange(html.startIndex..., in: html))
        var bookings: [ProviderBookingDraft] = []
        for match in matches {
            guard match.numberOfRanges == 4,
                  let url = group(html, match, 1),
                  let startRaw = group(html, match, 2),
                  let endRaw = group(html, match, 3),
                  let startAt = parseDate(startRaw),
                  let endAt = parseDate(endRaw) else { continue }
            bookings.append(draft(url: url, startAt: startAt, endAt: endAt))
        }
        return bookings
    }

    /// Fallback: reservation/confirmation links with nearby ISO dates.
    func parseMyTripsLinks(from html: String) -> [ProviderBookingDraft] {
        let linkPattern = #"href="(https?://(?:secure\.)?booking\.com/[^"]*(?:confirmation|mytrips|reservation|hotel)[^"]*)""#
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: [.caseInsensitive]) else {
            return []
        }
        let ns = html as NSString
        let matches = linkRegex.matches(in: html, options: [], range: NSRange(location: 0, length: ns.length))
        var bookings: [ProviderBookingDraft] = []
        let datePattern = #"(\d{4}-\d{2}-\d{2})"#
        guard let dateRegex = try? NSRegularExpression(pattern: datePattern, options: []) else { return [] }

        for match in matches {
            guard let url = group(html, match, 1) else { continue }
            let windowStart = max(0, match.range.location - 400)
            let windowEnd = min(ns.length, match.range.location + match.range.length + 800)
            let window = ns.substring(with: NSRange(location: windowStart, length: windowEnd - windowStart))
            let dateMatches = dateRegex.matches(in: window, options: [], range: NSRange(window.startIndex..., in: window))
            let dates = dateMatches.compactMap { m -> Date? in
                guard let raw = group(window, m, 1) else { return nil }
                return BookingComParsing.parseISODateTime(raw)
            }
            guard dates.count >= 2 else { continue }
            bookings.append(draft(url: url, startAt: dates[0], endAt: dates[1]))
        }
        return bookings
    }

    func draft(url: String, startAt: Date, endAt: Date) -> ProviderBookingDraft {
        let lower = url.lowercased()
        let bookingType: BookingType
        if lower.contains("hotel") || lower.contains("accommodation") || lower.contains("stays") {
            bookingType = .hotel
        } else if lower.contains("flight") || lower.contains("flug") {
            bookingType = .flight
        } else {
            bookingType = .hotel
        }
        return ProviderBookingDraft(
            provider: .booking,
            bookingType: bookingType,
            externalUrl: url,
            startAt: startAt,
            endAt: endAt
        )
    }

    func group(_ html: String, _ match: NSTextCheckingResult, _ index: Int) -> String? {
        guard let range = Range(match.range(at: index), in: html) else { return nil }
        return String(html[range])
    }

    func parseDate(_ raw: String) -> Date? {
        let day = raw.replacingOccurrences(of: #"T.*$"#, with: "", options: .regularExpression)
        return BookingComParsing.parseISODateTime(day) ?? BookingComParsing.parseGermanDate(day)
    }
}
