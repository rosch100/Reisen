import Foundation

/// Eine verwertbare Preiszeile: Betrag und nicht-leerer ISO-4217-Code.
public struct TripCostLine: Equatable, Sendable {
    public let amount: Decimal
    public let currencyCode: String

    public init(amount: Decimal, currencyCode: String) {
        self.amount = amount
        self.currencyCode = CurrencyCode.normalize(currencyCode)
    }

    /// Paar aus optionalem Betrag und Code; fehlendes Paar → `nil` (zählt als fehlend beim Mapper).
    public static func optional(amount: Double?, currencyCode: String?) -> TripCostLine? {
        guard let amount else { return nil }
        let code = CurrencyCode.normalize(currencyCode ?? "")
        guard !code.isEmpty else { return nil }
        guard let decimal = DecimalJSON.parse(amount) else { return nil }
        return TripCostLine(amount: decimal, currencyCode: code)
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
        var priced = 0
        for line in lines {
            let code = CurrencyCode.normalize(line.currencyCode)
            guard !code.isEmpty else { continue }
            totals[code, default: 0] += line.amount
            priced += 1
        }
        return TripCostSummary(
            totalsByCurrency: totals,
            pricedCount: priced,
            missingCount: missingCount
        )
    }

    /// ISO-Codes aufsteigend für stabile Nebeneinander-Anzeige.
    public var sortedCurrencyCodes: [String] {
        totalsByCurrency.keys.sorted()
    }

    /// Stabile Signatur für UI-Refresh (IDs allein reichen nicht bei Preis-Edits).
    public var costFingerprint: String {
        let parts = sortedCurrencyCodes.map { code in
            let amount = totalsByCurrency[code].map { "\($0)" } ?? "0"
            return "\(code)=\(amount)"
        }
        return parts.joined(separator: "|") + "#m\(missingCount)#p\(pricedCount)"
    }
}
