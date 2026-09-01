import Foundation
import Testing
import ReisenDomain
import ReisenAppCore

@Test func frankfurterDecode_mapsRatesToDecimal() throws {
    let json = """
    {"amount":1.0,"base":"EUR","date":"2026-08-31","rates":{"USD":1.1596,"GBP":0.85648}}
    """.data(using: .utf8)!
    let quote = try FrankfurterExchangeRateClient.decodeQuote(data: json, expectedBase: "EUR")
    #expect(quote.base == "EUR")
    #expect(quote.rates["USD"] == Decimal(string: "1.1596"))
    #expect(quote.rates["GBP"] == Decimal(string: "0.85648"))
}

@Test func frankfurterDecode_emptyRates_throws() {
    let json = #"{"amount":1.0,"base":"EUR","date":"2026-08-31","rates":{}}"#.data(using: .utf8)!
    #expect(throws: FrankfurterExchangeRateError.emptyRates) {
        try FrankfurterExchangeRateClient.decodeQuote(data: json, expectedBase: "EUR")
    }
}

@Test func frankfurterCache_hitSkipsStaleFalse() {
    let cache = ExchangeRateQuoteCache(maxAge: 3600)
    let quote = ExchangeRateQuote(base: "EUR", date: Date(), rates: ["USD": 1])
    cache.store(quote, fetchedAt: Date())
    #expect(cache.isStale(quote) == false)
    #expect(cache.quote(forBase: "EUR")?.rates["USD"] == 1)
}
