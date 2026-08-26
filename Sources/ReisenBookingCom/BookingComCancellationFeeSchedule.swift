import Foundation
import ReisenDomain

/// Fee-Schedule-Zeilen aus Booking.com Confirmation-HTML (SSOT laut HAR).
extension BookingComCancellationDeadlineParser {
    func hasFeeScheduleMarkup(_ html: String) -> Bool {
        let lower = html.lowercased()
        return lower.contains("e2e-cancellation-breakdown")
            || lower.contains("e2e-conf-cancellation-cost")
            || lower.contains("stornierungsgebühren")
            || lower.contains("cancellation fee")
    }

    /// HAR (`confirmation.html`): `e2e-cancellation-breakdown` mit
    /// „bis 10. August 2026 23:59: € 0“ / „ab 11. August 2026 00:00: € 121,64“.
    func parseFeeSchedule(from html: String, hotelOffsetSeconds: Int) -> [CancellationDeadline] {
        let source = feeScheduleSource(from: html)
        var deadlines = parseLongGermanFeeRows(from: source, hotelOffsetSeconds: hotelOffsetSeconds)
        if deadlines.isEmpty {
            deadlines = parseNumericGermanFeeRows(from: source, hotelOffsetSeconds: hotelOffsetSeconds)
        }
        return deadlines
    }

    func feeScheduleSource(from html: String) -> String {
        let normalized = BookingComParsing.normalizeEuroEntities(html)
        if let section = BookingComParsing.capture(
            #"(?s)e2e-conf-cancellation-cost.*?(?:gemäß der Zeitzone der Unterkunft|property(?:'s)? local time|in the property(?:'s)? time zone)"#,
            in: normalized
        ) {
            return section
        }
        if let section = BookingComParsing.capture(
            #"(?s)e2e-conf-cancellation-cost.*?</table>"#,
            in: normalized
        ) {
            return section
        }
        if let breakdown = BookingComParsing.capture(
            #"(?s)e2e-cancellation-breakdown.*?</ul>"#,
            in: normalized
        ) {
            return breakdown
        }
        return normalized
    }
}
