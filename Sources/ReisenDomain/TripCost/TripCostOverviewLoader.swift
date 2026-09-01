import Foundation

/// Ergebnis für die Reiseübersicht (SharedUI formatiert).
public enum TripCostOverviewResult: Equatable, Sendable {
    case empty
    case native(TripCostSummary)
    case converted(summary: TripCostSummary, preferredTotal: Decimal, preferredCurrency: String, quoteDate: Date)
    case conversionFailed(summary: TripCostSummary)
}

/// Lädt optional Kurse — bei Convert aus **kein** Provider-Aufruf.
public enum TripCostOverviewLoader {
    /// Sofort anzeigbares Ergebnis vor async FX (kein Flash „k. A.“, kein stale Converted).
    public static func immediate(summary: TripCostSummary) -> TripCostOverviewResult {
        summary.pricedCount == 0 && summary.missingCount == 0
            ? .empty
            : .native(summary)
    }

    public static func load(
        summary: TripCostSummary,
        convertEnabled: Bool,
        preferredCurrency: String,
        rates: ExchangeRateProviding
    ) async -> TripCostOverviewResult {
        let baseline = immediate(summary: summary)
        guard convertEnabled, summary.pricedCount > 0 else {
            return baseline
        }
        do {
            let quote = try await rates.latestQuote(base: preferredCurrency)
            let total = try TripCostConversion.convertedTotal(
                summary: summary,
                preferredCurrency: preferredCurrency,
                quote: quote
            )
            return .converted(
                summary: summary,
                preferredTotal: total,
                preferredCurrency: preferredCurrency,
                quoteDate: quote.date
            )
        } catch {
            return .conversionFailed(summary: summary)
        }
    }
}
