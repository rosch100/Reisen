import Foundation

/// Tagesaktueller Referenzkurs-Satz (ECB/Frankfurter o. ä.).
public struct ExchangeRateQuote: Equatable, Sendable {
    public var base: String
    public var date: Date
    public var rates: [String: Decimal]

    public init(base: String, date: Date, rates: [String: Decimal]) {
        self.base = base.uppercased()
        self.date = date
        self.rates = Dictionary(uniqueKeysWithValues: rates.map { ($0.key.uppercased(), $0.value) })
    }
}

public enum TripCostConversionError: Error, Equatable, Sendable {
    case missingRate(currencyCode: String)
}

public enum TripCostConversion {
    /// Rechnet alle Teilsammen in `preferredCurrency` um. Fehlender Kurs → Fehler (kein Partial-Fake).
    public static func convertedTotal(
        summary: TripCostSummary,
        preferredCurrency: String,
        quote: ExchangeRateQuote
    ) throws -> Decimal {
        let preferred = preferredCurrency.uppercased()
        var total: Decimal = 0
        for (code, amount) in summary.totalsByCurrency {
            if code == preferred {
                total += amount
                continue
            }
            let converted = try convert(amount: amount, from: code, to: preferred, quote: quote)
            total += converted
        }
        return total
    }

    public static func convert(
        amount: Decimal,
        from source: String,
        to target: String,
        quote: ExchangeRateQuote
    ) throws -> Decimal {
        let from = source.uppercased()
        let to = target.uppercased()
        if from == to { return amount }

        let base = quote.base
        // amount in `from` → base → `to`
        let amountInBase: Decimal
        if from == base {
            amountInBase = amount
        } else {
            guard let fromRate = quote.rates[from], fromRate != 0 else {
                throw TripCostConversionError.missingRate(currencyCode: from)
            }
            amountInBase = amount / fromRate
        }

        if to == base {
            return amountInBase
        }
        guard let toRate = quote.rates[to] else {
            throw TripCostConversionError.missingRate(currencyCode: to)
        }
        return amountInBase * toRate
    }
}
