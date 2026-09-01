import Foundation

/// Tagesaktueller Referenzkurs-Satz (ECB/Frankfurter o. ä.).
public struct ExchangeRateQuote: Equatable, Sendable {
    public var base: String
    public var date: Date
    public var rates: [String: Decimal]

    public init(base: String, date: Date, rates: [String: Decimal]) {
        self.base = CurrencyCode.normalize(base)
        self.date = date
        self.rates = Dictionary(uniqueKeysWithValues: rates.map { (CurrencyCode.normalize($0.key), $0.value) })
    }
}
