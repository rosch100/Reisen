import Foundation

/// Baut Preiszeilen aus Domain-optionalen Paaren (Data mappt SD darauf).
public enum TripCostLineBuilder {
    public static func summary(
        bookingPairs: [(amount: Double?, currency: String?)],
        gapPairs: [(amount: Double?, currency: String?)]
    ) -> TripCostSummary {
        var lines: [TripCostLine] = []
        var missing = 0
        for pair in bookingPairs + gapPairs {
            if let line = TripCostLine.optional(amount: pair.amount, currencyCode: pair.currency) {
                lines.append(line)
            } else {
                missing += 1
            }
        }
        return TripCostSummary.make(lines: lines, missingCount: missing)
    }
}
