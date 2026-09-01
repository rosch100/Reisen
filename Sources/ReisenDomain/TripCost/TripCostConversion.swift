import Foundation

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
        let preferred = CurrencyCode.normalize(preferredCurrency)
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
        let from = CurrencyCode.normalize(source)
        let to = CurrencyCode.normalize(target)
        if from == to { return amount }

        let base = quote.base
        let amountInBase: Decimal
        if from == base {
            amountInBase = amount
        } else {
            guard let fromRate = quote.rates[from], fromRate > 0 else {
                throw TripCostConversionError.missingRate(currencyCode: from)
            }
            amountInBase = amount / fromRate
        }

        if to == base {
            return amountInBase
        }
        guard let toRate = quote.rates[to], toRate > 0 else {
            throw TripCostConversionError.missingRate(currencyCode: to)
        }
        return amountInBase * toRate
    }
}
