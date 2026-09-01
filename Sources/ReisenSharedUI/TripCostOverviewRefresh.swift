import Foundation
import ReisenDomain

/// Geteilter Refresh für Trip-Kostenübersicht (macOS + iOS).
@MainActor
public enum TripCostOverviewRefresh {
    /// Sofort `immediate`, dann async Load; veraltete Tokens werden verworfen.
    public static func run(
        summary: TripCostSummary,
        convertEnabled: Bool,
        preferredCurrencyStored: String,
        rates: ExchangeRateProviding,
        setToken: @escaping (UUID) -> Void,
        setResult: @escaping (TripCostOverviewResult) -> Void,
        currentToken: @escaping () -> UUID
    ) {
        let token = UUID()
        let preferredCurrency = AppSettingsKeys.preferredCurrency(stored: preferredCurrencyStored)
        setToken(token)
        setResult(TripCostOverviewLoader.immediate(summary: summary))
        Task {
            let result = await TripCostOverviewLoader.load(
                summary: summary,
                convertEnabled: convertEnabled,
                preferredCurrency: preferredCurrency,
                rates: rates
            )
            guard currentToken() == token else { return }
            setResult(result)
        }
    }
}
