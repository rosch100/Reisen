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
        let parts = summary.sortedCurrencyCodes.compactMap { code -> String? in
            guard let amount = summary.totalsByCurrency[code] else { return nil }
            return formatAmount(amount, code)
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
        case .converted(_, let preferredTotal, let preferredCurrency, _):
            return defaultFormat(preferredTotal, preferredCurrency)
        }
    }

    public static func secondaryLine(for result: TripCostOverviewResult) -> String? {
        switch result {
        case .empty:
            return nil
        case .native(let summary):
            return missingSuffix(missingCount: summary.missingCount)
        case .converted(let summary, _, _, let quoteDate):
            let dateText = quoteDate.formatted(date: .abbreviated, time: .omitted)
            return joinedSecondary([
                sideBySide(summary: summary),
                L10n.format(.tripCostReferenceRateHint, dateText),
                missingSuffix(missingCount: summary.missingCount),
            ])
        case .conversionFailed(let summary):
            return joinedSecondary([
                L10n.string(.tripCostConversionUnavailable),
                missingSuffix(missingCount: summary.missingCount),
            ])
        }
    }

    public static func defaultFormat(_ amount: Decimal, _ currencyCode: String) -> String {
        Formatting.formatCurrencyAmount(amount, currencyCode: currencyCode)
    }

    private static func joinedSecondary(_ parts: [String?]) -> String? {
        let present = parts.compactMap { $0 }
        guard !present.isEmpty else { return nil }
        return present.joined(separator: " · ")
    }
}
