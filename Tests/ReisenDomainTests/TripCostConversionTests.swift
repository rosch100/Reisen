import Foundation
import Testing
import ReisenDomain

@Test func tripCostConversion_sameCurrency_passthrough() throws {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 50, currencyCode: "EUR")],
        missingCount: 0
    )
    let quote = ExchangeRateQuote(base: "EUR", date: Date(timeIntervalSince1970: 0), rates: ["USD": Decimal(string: "1.1")!])
    let total = try TripCostConversion.convertedTotal(summary: summary, preferredCurrency: "EUR", quote: quote)
    #expect(total == 50)
}

@Test func tripCostConversion_EURAndUSD_toEUR() throws {
    // Quote base EUR: USD rate 1.1 means 1 EUR = 1.1 USD → 110 USD = 100 EUR
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: 100, currencyCode: "EUR"),
            TripCostLine(amount: 110, currencyCode: "USD"),
        ],
        missingCount: 0
    )
    let quote = ExchangeRateQuote(
        base: "EUR",
        date: Date(timeIntervalSince1970: 0),
        rates: ["USD": Decimal(string: "1.1")!]
    )
    let total = try TripCostConversion.convertedTotal(summary: summary, preferredCurrency: "EUR", quote: quote)
    #expect(total == 200)
}

@Test func tripCostConversion_missingRate_throws() {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 10, currencyCode: "GBP")],
        missingCount: 0
    )
    let quote = ExchangeRateQuote(base: "EUR", date: Date(timeIntervalSince1970: 0), rates: ["USD": 1])
    #expect(throws: TripCostConversionError.missingRate(currencyCode: "GBP")) {
        try TripCostConversion.convertedTotal(summary: summary, preferredCurrency: "EUR", quote: quote)
    }
}

@Test func tripCostConversion_zeroTargetRate_throws() {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 10, currencyCode: "EUR")],
        missingCount: 0
    )
    let quote = ExchangeRateQuote(
        base: "USD",
        date: Date(timeIntervalSince1970: 0),
        rates: ["EUR": 0]
    )
    #expect(throws: TripCostConversionError.missingRate(currencyCode: "EUR")) {
        try TripCostConversion.convertedTotal(summary: summary, preferredCurrency: "USD", quote: quote)
    }
}

@Test func tripCostLine_init_normalizesCurrencyCode() {
    let line = TripCostLine(amount: 1, currencyCode: " eur ")
    #expect(line.currencyCode == "EUR")
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: 1, currencyCode: " eur "),
            TripCostLine(amount: 2, currencyCode: "EUR"),
        ],
        missingCount: 0
    )
    #expect(summary.totalsByCurrency["EUR"] == 3)
    #expect(summary.totalsByCurrency.count == 1)
    #expect(summary.costFingerprint.contains("EUR="))
}
