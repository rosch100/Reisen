import Foundation
import WebKit

/// SSOT: Heuristik → applies / Account-Skip / Live-Fetch für Session-Probes.
public enum ProviderSessionLiveProbe {
    public static func applies(to heuristic: ProviderSessionStatusHeuristic) -> ((URL) -> Bool)? {
        switch heuristic {
        case .shouldProbeOpodo:
            return OpodoSessionProbe.applies(to:)
        case .shouldProbeTraveloka:
            return TravelokaSessionProbe.applies(to:)
        case .shouldProbeBilligerMietwagen:
            return BilligerMietwagenSessionProbe.applies(to:)
        case .shouldProbeCheck24:
            return Check24SessionProbe.applies(to:)
        case .sessionReady, .needsLogin, .unknown:
            return nil
        }
    }

    /// Opodo/Traveloka: Account-URL braucht keine GraphQL-/whoami-Probe.
    public static func skipsAccountPageProbe(_ heuristic: ProviderSessionStatusHeuristic) -> Bool {
        switch heuristic {
        case .shouldProbeOpodo, .shouldProbeTraveloka:
            return true
        case .shouldProbeBilligerMietwagen, .shouldProbeCheck24,
             .sessionReady, .needsLogin, .unknown:
            return false
        }
    }

    public static func fetchIsLoggedIn(
        _ heuristic: ProviderSessionStatusHeuristic,
        using webView: WKWebView,
        additionalHintURLs: [URL] = []
    ) async throws -> Bool? {
        switch heuristic {
        case .shouldProbeOpodo:
            return try await OpodoSessionProbe.fetchIsLoggedIn(using: webView)
        case .shouldProbeTraveloka:
            return try await TravelokaSessionProbe.fetchIsLoggedIn(
                using: webView,
                additionalHintURLs: additionalHintURLs
            )
        case .shouldProbeBilligerMietwagen:
            return try await BilligerMietwagenSessionProbe.fetchIsLoggedIn(using: webView)
        case .shouldProbeCheck24:
            return try await Check24SessionProbe.fetchIsLoggedIn(using: webView)
        case .sessionReady, .needsLogin, .unknown:
            return nil
        }
    }
}
