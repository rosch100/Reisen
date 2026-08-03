import Foundation
import ReisenDomain

/// Parser für Stornofristen aus Booking.com-HTML (Confirmation Fee-Schedule + Heuristik).
///
/// HAR Confirmation (`e2e-cancellation-breakdown`): Fee-Schedule ist die SSOT
/// („bis … / ab …“, Beträge, „gemäß der Zeitzone der Unterkunft“).
public struct BookingComCancellationDeadlineParser: Sendable {
    public init() {}

    /// - Parameter hotelOffsetSeconds: Pflicht für korrekte Ortszeiten; ohne Offset keine Fristen
    ///   (kein stilles UTC, HAR: Zeitzone der Unterkunft).
    public func parseDeadlines(from html: String, hotelOffsetSeconds: Int? = nil) -> [CancellationDeadline] {
        guard let offset = hotelOffsetSeconds else { return [] }

        let feeSchedule = parseFeeSchedule(from: html, hotelOffsetSeconds: offset)
        if !feeSchedule.isEmpty {
            return dedupe(feeSchedule)
        }
        // Markup vorhanden, aber Zeilen nicht lesbar → kein Keyword-Müll (z. B. falsches „vor dem“).
        if hasFeeScheduleMarkup(html) {
            return []
        }
        return dedupe(parseKeywordWindows(from: html, hotelOffsetSeconds: offset))
    }

    func dedupe(_ deadlines: [CancellationDeadline]) -> [CancellationDeadline] {
        var byKey: [String: CancellationDeadline] = [:]
        for d in deadlines {
            let feeKey = d.cancellationFeeAmount.map { String(Int(($0 * 100).rounded())) } ?? ""
            let key = "\(Int(d.deadlineAt.timeIntervalSince1970))|\(d.isFreeCancellation)|\(feeKey)"
            byKey[key] = d
        }
        return byKey.values.sorted { $0.deadlineAt < $1.deadlineAt }
    }
}
