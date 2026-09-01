import Foundation
import ReisenDomain

/// Formatierung der Trip-Kostensumme für Übersicht (kein Mapping).
public enum TripCostDisplayText {
    public static func sideBySide(
        summary: TripCostSummary,
        formatAmount: (Decimal, String) -> String = defaultFormat
    ) -> String {
        guard summary.pricedCount > 0 else {
            return L10n.string(.commonNotAvailable)
        }
        let parts = summary.sortedCurrencyCodes.map { code in
            formatAmount(summary.totalsByCurrency[code] ?? 0, code)
        }
        return parts.joined(separator: " · ")
    }

    public static func missingSuffix(missingCount: Int) -> String? {
        guard missingCount > 0 else { return nil }
        return L10n.format(.tripCostMissingPrices, missingCount)
    }

    public static func primaryLine(for result: TripCostOverviewResult) -> String {
        switch result {
        case .empty:
            return L10n.string(.commonNotAvailable)
        case .native(let summary), .conversionFailed(let summary):
            return sideBySide(summary: summary)
        case .converted(let summary, let preferredTotal, let preferredCurrency, _):
            let converted = defaultFormat(preferredTotal, preferredCurrency)
            let originals = sideBySide(summary: summary)
            return "\(converted) (\(originals))"
        }
    }

    public static func secondaryLine(for result: TripCostOverviewResult) -> String? {
        switch result {
        case .empty:
            return nil
        case .native(let summary):
            return missingSuffix(missingCount: summary.missingCount)
        case .converted(let summary, _, _, let quoteDate):
            let missing = missingSuffix(missingCount: summary.missingCount)
            let dateText = quoteDate.formatted(date: .abbreviated, time: .omitted)
            let hint = L10n.format(.tripCostReferenceRateHint, dateText)
            if let missing {
                return "\(hint) · \(missing)"
            }
            return hint
        case .conversionFailed(let summary):
            let fail = L10n.string(.tripCostConversionUnavailable)
            if let missing = missingSuffix(missingCount: summary.missingCount) {
                return "\(fail) · \(missing)"
            }
            return fail
        }
    }

    public static func defaultFormat(_ amount: Decimal, _ currencyCode: String) -> String {
        let doubleValue = NSDecimalNumber(decimal: amount).doubleValue
        return Formatting.formatCurrencyAmount(doubleValue, currencyCode: currencyCode)
    }
}
