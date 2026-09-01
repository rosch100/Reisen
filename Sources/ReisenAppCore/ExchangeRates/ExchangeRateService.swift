import Foundation
import ReisenDomain

/// Geteilter Frankfurter-Client, damit der In-Memory-Cache über Overview-Refreshes hält.
public enum ExchangeRateService {
    public static let sharedClient = FrankfurterExchangeRateClient()
}
