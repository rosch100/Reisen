import Foundation
import ReisenDomain

public struct ActivityListParser {
    public init() {}

    public func parseActivityListHTML(_ html: String) throws -> ParsedActivity {
        // Live-API und HAR liefern JSON mit activities — nicht zwingend HTML mit hrefs.
        // Wenn der Payload wie Activities-JSON aussieht, JSON-Fehler nicht als „keine Links“
        // verschleiern (kein stiller Fallthrough auf HTML-Heuristik).
        if looksLikeActivitiesJSON(html) {
            return try parseActivitiesJSON(from: html)
        }

        let candidateLinks = extractBookingLinks(from: html)
        let parsedBookings = candidateLinks.compactMap { link in
            try? parseBookingWindow(for: link, in: html)
        }

        let cancellationDeadlines = (try? parseCancellationDeadlines(from: html)) ?? []
        return ParsedActivity(bookings: parsedBookings, cancellationDeadlines: cancellationDeadlines)
    }
}
