import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func tripCostDisplay_sideBySide_andMissing() {
    let summary = TripCostSummary.make(
        lines: [
            TripCostLine(amount: 10, currencyCode: "EUR"),
            TripCostLine(amount: 5, currencyCode: "USD"),
        ],
        missingCount: 2
    )
    let text = TripCostDisplayText.sideBySide(summary: summary) { amount, code in
        "\(amount) \(code)"
    }
    #expect(text == "10 EUR · 5 USD")
    #expect(TripCostDisplayText.missingSuffix(missingCount: 2) != nil)
}

@Test func currencySettings_entry_readsSameKeysAsSettingsStorage() {
    let suite = "ReisenTests.currencySettingsEntry"
    let defaults = UserDefaults(suiteName: suite)!
    defaults.removePersistentDomain(forName: suite)

    defaults.set("GBP", forKey: AppSettingsKeys.preferredCurrencyCode)
    defaults.set(true, forKey: AppSettingsKeys.convertAmountsToPreferredCurrency)

    #expect(AppSettingsKeys.preferredCurrency(defaults: defaults) == "GBP")
    #expect(AppSettingsKeys.convertsAmountsToPreferredCurrency(defaults: defaults) == true)

    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 12, currencyCode: "EUR")],
        missingCount: 0
    )
    let convertOn = AppSettingsKeys.convertsAmountsToPreferredCurrency(defaults: defaults)
    #expect(convertOn == true)
    let native = TripCostOverviewResult.native(summary)
    #expect(TripCostDisplayText.primaryLine(for: native).isEmpty == false)
}

@Test func tripCostDisplay_convertedKeepsOriginalsAndFailedKeepsNative() {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: 10, currencyCode: "EUR")],
        missingCount: 0
    )
    let converted = TripCostOverviewResult.converted(
        summary: summary,
        preferredTotal: 11,
        preferredCurrency: "USD",
        quoteDate: Date(timeIntervalSince1970: 0)
    )
    let primary = TripCostDisplayText.primaryLine(for: converted)
    #expect(primary.contains("("))
    #expect(TripCostDisplayText.secondaryLine(for: converted) != nil)

    let failed = TripCostOverviewResult.conversionFailed(summary: summary)
    #expect(TripCostDisplayText.secondaryLine(for: failed)?.contains(L10n.string(.tripCostConversionUnavailable)) == true)
}
