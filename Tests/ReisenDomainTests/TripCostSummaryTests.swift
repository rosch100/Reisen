import Foundation
import Testing
import ReisenDomain

@Test func tripCostSummary_empty_hasNoTotalsAndZeroCounts() {
    let summary = TripCostSummary.make(lines: [], missingCount: 0)
    #expect(summary.totalsByCurrency.isEmpty)
    #expect(summary.pricedCount == 0)
    #expect(summary.missingCount == 0)
}

@Test func tripCostSummary_singleEUR_sumsThatCurrency() throws {
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: Decimal(string: "10.50")!, currencyCode: "EUR"),
            TripCostLine(amount: Decimal(string: "1.50")!, currencyCode: "EUR"),
        ],
        missingCount: 0
    )
    #expect(summary.totalsByCurrency["EUR"] == Decimal(string: "12"))
    #expect(summary.pricedCount == 2)
    #expect(summary.missingCount == 0)
}

@Test func tripCostSummary_EURAndUSD_keepsSeparateTotals() throws {
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: Decimal(string: "100")!, currencyCode: "EUR"),
            TripCostLine(amount: Decimal(string: "40")!, currencyCode: "USD"),
            TripCostLine(amount: Decimal(string: "10")!, currencyCode: "EUR"),
        ],
        missingCount: 1
    )
    #expect(summary.totalsByCurrency["EUR"] == Decimal(string: "110"))
    #expect(summary.totalsByCurrency["USD"] == Decimal(string: "40"))
    #expect(summary.totalsByCurrency.count == 2)
    #expect(summary.pricedCount == 3)
    #expect(summary.missingCount == 1)
}

@Test func tripCostLine_optionalPair_requiresAmountAndNonEmptyCurrency() {
    #expect(TripCostLine.optional(amount: 10, currencyCode: "EUR") != nil)
    #expect(TripCostLine.optional(amount: nil, currencyCode: "EUR") == nil)
    #expect(TripCostLine.optional(amount: 10, currencyCode: nil) == nil)
    #expect(TripCostLine.optional(amount: 10, currencyCode: "  ") == nil)
    #expect(TripCostLine.optional(amount: 10, currencyCode: "") == nil)
}
