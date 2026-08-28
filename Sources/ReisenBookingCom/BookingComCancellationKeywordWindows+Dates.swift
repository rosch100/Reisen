import Foundation
import ReisenDomain

extension BookingComCancellationDeadlineParser {
    func deadlineDate(from snippet: String, hotelOffsetSeconds: Int) -> Date? {
        let lower = snippet.lowercased()
        if lower.contains("vor dem") || lower.contains("before") {
            return BookingComParsing.parseExclusiveGermanPolicyDate(
                in: snippet,
                offsetSeconds: hotelOffsetSeconds
            )
        }
        return firstDateInSnippet(snippet, hotelOffsetSeconds: hotelOffsetSeconds)
    }

    func firstDateInSnippet(_ snippet: String, hotelOffsetSeconds: Int) -> Date? {
        if let match = BookingComParsing.capture(
            #"(\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:?\d{2}))"#,
            in: snippet
        ), let date = ISODateTime.parse(match) {
            return date
        }
        if let match = BookingComParsing.capture(
            #"(\d{2}\.\d{2}\.\d{4}\s+\d{2}:\d{2})"#,
            in: snippet
        ), let date = BookingComParsing.parseGermanDateTime(match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        if let match = BookingComParsing.capture(
            #"(\d{1,2}\.\s*[A-Za-zÄÖÜäöüß]+\s+\d{4}\s+\d{2}:\d{2})"#,
            in: snippet
        ), let date = BookingComParsing.parseGermanLongDateTime(in: match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        if let match = BookingComParsing.capture(#"(\d{2}\.\d{2}\.\d{4})"#, in: snippet),
           let date = BookingComParsing.parseGermanDateEndOfDay(match, offsetSeconds: hotelOffsetSeconds) {
            return date
        }
        return BookingComParsing.parseGermanLongDate(
            in: snippet,
            endOfDay: true,
            offsetSeconds: hotelOffsetSeconds
        )
    }
}
