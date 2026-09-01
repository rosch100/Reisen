import Foundation
import Testing
import ReisenDomain
import ReisenSharedUI

@Test func formatCurrencyAmount_usesGermanGroupingAndDecimal_forDeLocale() {
    let text = L10n.withLocale(Locale(identifier: "de_DE")) {
        Formatting.formatCurrencyAmount(1234.5 as Double, currencyCode: "EUR")
    }
    #expect(text.contains("1.234,50") || text.contains("1.234,5"))
    #expect(text.contains("€") || text.contains("EUR"))
}

@Test func formatCurrencyAmount_usesEnglishGroupingAndDecimal_forEnLocale() {
    let text = L10n.withLocale(Locale(identifier: "en_US")) {
        Formatting.formatCurrencyAmount(1234.5 as Double, currencyCode: "USD")
    }
    #expect(text.contains("1,234.50") || text.contains("1,234.5"))
    #expect(text.contains("$") || text.contains("USD"))
}

@Test func formatCurrencyAmount_explicitLocaleOverridesTaskLocale() {
    let german = Formatting.formatCurrencyAmount(
        Decimal(10),
        currencyCode: "EUR",
        locale: Locale(identifier: "de_DE")
    )
    let english = Formatting.formatCurrencyAmount(
        Decimal(10),
        currencyCode: "EUR",
        locale: Locale(identifier: "en_US")
    )
    #expect(german != english)
    #expect(german.contains(","))
    #expect(english.contains("."))
}

@Test func tripCostDisplay_defaultFormat_followsL10nLocale() {
    let summary = TripCostSummary.make(
        lines: [TripCostLine(amount: Decimal(string: "1234.5")!, currencyCode: "EUR")],
        missingCount: 0
    )
    let en = L10n.withLocale(Locale(identifier: "en_GB")) {
        TripCostDisplayText.sideBySide(summary: summary)
    }
    let de = L10n.withLocale(Locale(identifier: "de_DE")) {
        TripCostDisplayText.sideBySide(summary: summary)
    }
    #expect(en != de)
    #expect(en.contains(",") && en.contains(".")) // en grouping + decimal
    #expect(de.contains("1.234,50") || de.contains("1.234,5"))
}
