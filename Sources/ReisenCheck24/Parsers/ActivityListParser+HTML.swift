import Foundation
import ReisenDomain

extension ActivityListParser {
    func extractBookingLinks(from html: String) -> [String] {
        let pattern = #"href="([^"]+)""#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex else { return [] }

        let ns = html as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        let links: [String] = matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let range = match.range(at: 1)
            guard range.location != NSNotFound else { return nil }
            return ns.substring(with: range)
        }

        return links.filter { href in
            let lower = href.lowercased()
            return lower.contains("booking")
                || lower.contains("buchung")
                || lower.contains("hotel")
                || lower.contains("flug")
                || lower.contains("flight")
                || lower.contains("ferry")
                || lower.contains("faehre")
                || lower.contains("reise")
        }
    }

    func parseBookingWindow(for href: String, in html: String) throws -> ParsedBooking {
        let ns = html as NSString
        guard html.lowercased().range(of: href.lowercased()) != nil else {
            throw Check24ParseError.activityListNotRecognized
        }
        let nsStart = ns.range(of: href, options: [.caseInsensitive]).location
        guard nsStart != NSNotFound else {
            throw Check24ParseError.activityListNotRecognized
        }

        let snippetStart = nsStart
        let snippetLength = min(600, ns.length - snippetStart)
        let snippet = ns.substring(with: NSRange(location: snippetStart, length: snippetLength))

        let type = bookingType(from: href)
        let dates = try extractDates(from: snippet)
        guard dates.count >= 2 else {
            throw Check24ParseError.noBookingDatesFound
        }

        return ParsedBooking(
            type: type,
            title: extractAnchorText(around: snippet),
            confirmationCode: nil,
            externalUrl: normalizeExternalUrl(href),
            startAt: dates[0],
            endAt: dates[1],
            locationFrom: nil,
            locationTo: nil,
            locationFromAddress: nil,
            locationToAddress: nil,
            status: .unknown,
            details: nil
        )
    }

    func parseCancellationDeadlines(from html: String) throws -> [ParsedCancellationDeadline] {
        let ns = html as NSString
        let pattern = #"(?is)storn[^\d]{0,120}((\d{2})\.(\d{2})\.(\d{4}))"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: html, options: [], range: fullRange)

        if matches.isEmpty {
            throw Check24ParseError.noCancellationDeadlineFound
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"

        return matches.compactMap { match in
            guard match.numberOfRanges >= 2 else { return nil }
            let dateString = ns.substring(with: match.range(at: 1))
            guard let date = formatter.date(from: dateString) else { return nil }
            return ParsedCancellationDeadline(
                deadlineAt: date,
                policyText: nil,
                isStrict: true,
                isFreeCancellation: false,
                hotelOffsetSeconds: nil,
                cancellationFeeAmount: nil
            )
        }
    }

    private func bookingType(from href: String) -> BookingType {
        let lower = href.lowercased()
        if lower.contains("hotel") || lower.contains("ferienwohnung") { return .hotel }
        if lower.contains("flug") || lower.contains("flight") { return .flight }
        if lower.contains("ferry") || lower.contains("faehre") { return .ferry }
        return .other
    }

    private func extractDates(from snippet: String) throws -> [Date] {
        let pattern = #"\b(\d{2})\.(\d{2})\.(\d{4})\b"#
        let regex = try NSRegularExpression(pattern: pattern, options: [])
        let ns = snippet as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        let matches = regex.matches(in: snippet, options: [], range: fullRange)

        if matches.isEmpty {
            throw Check24ParseError.noBookingDatesFound
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "de_DE_POSIX")
        formatter.dateFormat = "dd.MM.yyyy"

        return matches.compactMap { match in
            let full = ns.substring(with: match.range(at: 0))
            return formatter.date(from: full)
        }
    }

    private func extractAnchorText(around snippet: String) -> String? {
        let pattern = #">([^<]{1,80})</a>"#
        let regex = try? NSRegularExpression(pattern: pattern, options: [])
        guard let regex else { return nil }
        let ns = snippet as NSString
        let fullRange = NSRange(location: 0, length: ns.length)
        guard let match = regex.firstMatch(in: snippet, options: [], range: fullRange) else { return nil }
        guard match.numberOfRanges >= 2 else { return nil }
        let range = match.range(at: 1)
        guard range.location != NSNotFound else { return nil }
        return ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizeExternalUrl(_ href: String) -> String? {
        if href.starts(with: "http://") || href.starts(with: "https://") {
            return normalizeBookingDetailURL(href)
        }
        if href.starts(with: "/") {
            return "https://kundenbereich.check24.de" + href
        }
        return nil
    }
}
