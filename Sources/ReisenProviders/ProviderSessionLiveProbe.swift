import Foundation
import WebKit

/// SSOT: Heuristik → applies / Account-Skip / Live-Fetch für Session-Probes.
public enum ProviderSessionLiveProbe {
    /// Startkonfiguration einer Live-Probe, oder `nil` wenn keine Probe laufen soll.
    ///
    /// Check24: Produktseiten bei schon grüner Ampel überspringen; Marketing-Homepage
    /// (`/` / leer) trotzdem erneut prüfen (Logout → Homepage ohne Login-URL).
    public static func prepare(
        _ heuristic: ProviderSessionStatusHeuristic,
        sessionAlreadyReady: Bool,
        url: URL? = nil
    ) -> (applies: (URL) -> Bool, skipsAccountPage: Bool)? {
        guard let kind = Kind.from(heuristic) else { return nil }
        if sessionAlreadyReady,
           kind == .check24,
           !isCheck24AmbiguousLanding(url)
        {
            return nil
        }
        return (kind.applies, kind.skipsAccountPage)
    }

    public static func fetchIsLoggedIn(
        _ heuristic: ProviderSessionStatusHeuristic,
        using webView: WKWebView,
        additionalHintURLs: [URL] = []
    ) async throws -> Bool? {
        guard let kind = Kind.from(heuristic) else { return nil }
        return try await kind.fetchIsLoggedIn(using: webView, additionalHintURLs: additionalHintURLs)
    }

    /// SSO-/Logout-Landing ohne Account-/Login-Pfad — Ampel muss neu verifiziert werden.
    private static func isCheck24AmbiguousLanding(_ url: URL?) -> Bool {
        guard let url, Check24SessionProbe.applies(to: url) else { return false }
        let path = url.path
        return path.isEmpty || path == "/"
    }

    /// Eine Abbildung Heuristik → Probe-Verhalten (SSOT statt paralleler Switches).
    private enum Kind {
        case opodo
        case traveloka
        case billigerMietwagen
        case check24

        static func from(_ heuristic: ProviderSessionStatusHeuristic) -> Kind? {
            switch heuristic {
            case .shouldProbeOpodo: return .opodo
            case .shouldProbeTraveloka: return .traveloka
            case .shouldProbeBilligerMietwagen: return .billigerMietwagen
            case .shouldProbeCheck24: return .check24
            case .sessionReady, .needsLogin, .unknown: return nil
            }
        }

        var applies: (URL) -> Bool {
            switch self {
            case .opodo: return OpodoSessionProbe.applies(to:)
            case .traveloka: return TravelokaSessionProbe.applies(to:)
            case .billigerMietwagen: return BilligerMietwagenSessionProbe.applies(to:)
            case .check24: return Check24SessionProbe.applies(to:)
            }
        }

        var skipsAccountPage: Bool {
            switch self {
            case .opodo, .traveloka: return true
            case .billigerMietwagen, .check24: return false
            }
        }

        func fetchIsLoggedIn(
            using webView: WKWebView,
            additionalHintURLs: [URL]
        ) async throws -> Bool? {
            switch self {
            case .opodo:
                return try await OpodoSessionProbe.fetchIsLoggedIn(using: webView)
            case .traveloka:
                return try await TravelokaSessionProbe.fetchIsLoggedIn(
                    using: webView,
                    additionalHintURLs: additionalHintURLs
                )
            case .billigerMietwagen:
                return try await BilligerMietwagenSessionProbe.fetchIsLoggedIn(using: webView)
            case .check24:
                return try await Check24SessionProbe.fetchIsLoggedIn(using: webView)
            }
        }
    }
}
