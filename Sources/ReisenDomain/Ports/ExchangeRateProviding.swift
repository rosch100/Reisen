import Foundation

/// Port für Referenzkurs-Abruf (CI mockt; Produkt: Frankfurter).
public protocol ExchangeRateProviding: Sendable {
    func latestQuote(base: String) async throws -> ExchangeRateQuote
}
