import Foundation

/// Eine verwertbare Preiszeile: Betrag und nicht-leerer ISO-4217-Code.
public struct TripCostLine: Equatable, Sendable {
    public var amount: Decimal
    public var currencyCode: String

    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = currencyCode
    }

    /// Paar aus optionalem Betrag und Code; fehlendes Paar → `nil` (zählt als fehlend beim Mapper).
    public static func optional(amount: Double?, currencyCode: String?) -> TripCostLine? {
        guard let amount else { return nil }
        guard let raw = currencyCode?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return TripCostLine(amount: Decimal(amount), currencyCode: raw.uppercased())
    }
}

/// Kostensumme einer Reise: Summen **pro Währung**, nie gemischt.
public struct TripCostSummary: Equatable, Sendable {
    public var totalsByCurrency: [String: Decimal]
    public var pricedCount: Int
    public var missingCount: Int

    public init(totalsByCurrency: [String: Decimal], pricedCount: Int, missingCount: Int) {
        self.totalsByCurrency = totalsByCurrency
        self.pricedCount = pricedCount
        self.missingCount = missingCount
    }

    public static func make(lines: [TripCostLine], missingCount: Int) -> TripCostSummary {
        var totals: [String: Decimal] = [:]
        for line in lines {
            let code = line.currencyCode.uppercased()
            totals[code, default: 0] += line.amount
        }
        return TripCostSummary(
            totalsByCurrency: totals,
            pricedCount: lines.count,
            missingCount: missingCount
        )
    }

    /// ISO-Codes aufsteigend für stabile Nebeneinander-Anzeige.
    public var sortedCurrencyCodes: [String] {
        totalsByCurrency.keys.sorted()
    }
}
