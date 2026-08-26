import Foundation
import ReisenDomain

enum AirbnbScheduledEventsPayment {
    static func parse(rows: [AirbnbScheduledEventRow]) -> BookingRateDetails? {
        let row = rows.first(where: { $0.id == "payment_summary" })
        guard let row, let subtitle = row.subtitle else { return nil }
        guard let amount = parseAmount(from: subtitle) else { return nil }
        let cleaned = subtitle.replacingOccurrences(of: "\u{00A0}", with: " ")
        let currency: String? = cleaned.contains("€") ? "EUR" : nil
        return BookingRateDetails(
            totalPriceAmount: amount,
            totalPriceCurrency: currency,
            boardType: .unknown,
            lastParsedAt: Date()
        )
    }

    /// Expected pattern: "52,56 €" (German decimal separator).
    static func parseAmount(from subtitle: String) -> Double? {
        let cleaned = subtitle.replacingOccurrences(of: "\u{00A0}", with: " ")
        guard let match = cleaned.range(of: #"([0-9]{1,3}([.,][0-9]{2})?)"#, options: .regularExpression) else {
            return nil
        }
        let numberToken = String(cleaned[match])
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: ",", with: ".")
        return Double(numberToken)
    }
}
