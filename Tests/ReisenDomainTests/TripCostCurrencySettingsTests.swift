import Foundation
import Testing
import ReisenDomain

@Test func preferredCurrencyOptions_includesLocaleAndStored() {
    let locale = Locale(identifier: "de_DE")
    let codes = PreferredCurrencyOptions.codes(locale: locale, including: "ISK")
    #expect(codes.contains("EUR"))
    #expect(codes.contains("ISK"))
    #expect(codes.firstIndex(of: "ISK")! < codes.firstIndex(of: "USD")!)
    #expect(PreferredCurrencyOptions.displayName(for: "EUR", locale: locale).hasPrefix("EUR"))
}

@Test func currencySettings_preferredDefaultsToLocaleOrEUR() {
    let suite = "ReisenTests.preferredCurrency"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(AppSettingsKeys.preferredCurrencyCode == "reisen_preferredCurrencyCode")
    var locale = Locale(identifier: "de_DE")
    #expect(AppSettingsKeys.preferredCurrency(defaults: defaults, locale: locale) == "EUR")
    AppSettingsKeys.setPreferredCurrency("usd", defaults: defaults)
    #expect(AppSettingsKeys.preferredCurrency(defaults: defaults, locale: locale) == "USD")
}

@Test func currencySettings_convertDefaultsOff() {
    let suite = "ReisenTests.convertCurrency"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)
    #expect(AppSettingsKeys.convertAmountsToPreferredCurrency == "reisen_convertAmountsToPreferredCurrency")
    #expect(AppSettingsKeys.convertsAmountsToPreferredCurrency(defaults: defaults) == false)
    AppSettingsKeys.setConvertsAmountsToPreferredCurrency(true, defaults: defaults)
    #expect(AppSettingsKeys.convertsAmountsToPreferredCurrency(defaults: defaults) == true)
}

@Test func tripCostLineBuilder_unpairedAmountOrCurrency_countsMissing() {
    let summary = TripCostLineBuilder.summary(
        bookingPairs: [
            (100, "EUR"),
            (50, nil),
            (nil, "USD"),
            (10, "  "),
        ],
        gapPairs: [(20, "USD")]
    )
    #expect(summary.totalsByCurrency["EUR"] == 100)
    #expect(summary.totalsByCurrency["USD"] == 20)
    #expect(summary.pricedCount == 2)
    #expect(summary.missingCount == 3)
}

final class SpyExchangeRates: ExchangeRateProviding, @unchecked Sendable {
    private(set) var fetchCount = 0
    var quote: ExchangeRateQuote

    init(quote: ExchangeRateQuote) {
        self.quote = quote
    }

    func latestQuote(base: String) async throws -> ExchangeRateQuote {
        fetchCount += 1
        return quote
    }
}

@Test func tripCostOverviewLoader_convertOff_doesNotFetch() async {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 10, currencyCode: "EUR")],
        missingCount: 0
    )
    let spy = SpyExchangeRates(
        quote: ExchangeRateQuote(base: "EUR", date: Date(), rates: ["USD": 1])
    )
    let result = await TripCostOverviewLoader.load(
        summary: summary,
        convertEnabled: false,
        preferredCurrency: "EUR",
        rates: spy
    )
    #expect(spy.fetchCount == 0)
    guard case .native = result else {
        Issue.record("expected native")
        return
    }
}

@Test func tripCostOverviewLoader_convertOn_fetchesOnce() async {
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: 100, currencyCode: "EUR"),
            TripCostLine(amount: 110, currencyCode: "USD"),
        ],
        missingCount: 0
    )
    let spy = SpyExchangeRates(
        quote: ExchangeRateQuote(base: "EUR", date: Date(timeIntervalSince1970: 1_700_000_000), rates: ["USD": Decimal(string: "1.1")!])
    )
    let result = await TripCostOverviewLoader.load(
        summary: summary,
        convertEnabled: true,
        preferredCurrency: "EUR",
        rates: spy
    )
    #expect(spy.fetchCount == 1)
    guard case .converted(_, let total, let currency, _) = result else {
        Issue.record("expected converted")
        return
    }
    #expect(currency == "EUR")
    #expect(total == 200)
}
