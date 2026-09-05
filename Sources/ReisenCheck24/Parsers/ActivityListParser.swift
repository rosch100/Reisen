import Foundation
import ReisenDomain
import ReisenDiagnostics

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
        var droppedBookingWindows = 0
        let parsedBookings = candidateLinks.compactMap { link -> ParsedBooking? in
            do {
                return try parseBookingWindow(for: link, in: html)
            } catch {
                droppedBookingWindows += 1
                return nil
            }
        }
        if droppedBookingWindows > 0 {
            Self.recordHTMLBookingWindowDrops(count: droppedBookingWindows)
        }

        let cancellationDeadlines: [ParsedCancellationDeadline]
        do {
            cancellationDeadlines = try parseCancellationDeadlines(from: html)
        } catch Check24ParseError.noCancellationDeadlineFound {
            cancellationDeadlines = []
        }
        return ParsedActivity(bookings: parsedBookings, cancellationDeadlines: cancellationDeadlines)
    }

    private static func recordHTMLBookingWindowDrops(count: Int) {
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: UUID(),
                        providerID: .check24,
                        operation: "check24_catalog"
                    ),
                    component: "ActivityListParser",
                    phase: "html_booking_window",
                    event: "booking_window_dropped",
                    result: .skipped,
                    reason: "count_\(count)",
                    visibility: .publicDiagnostic
                )
            )
        }
    }
}
