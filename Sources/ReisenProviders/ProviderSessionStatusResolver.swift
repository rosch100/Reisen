import Foundation

/// Plattformneutrale Heuristik, ob eine Provider-Seite eher „Login erforderlich“,
/// „bereits angemeldet“ oder eine Session-Probe nötig signalisiert.
///
/// Wichtig: Das hier ist nur die URL-Klassifikation. Cookie-/Session-Probing
/// passiert weiterhin in der jeweiligen Session-UI (macOS/iOS).
public enum ProviderSessionStatusHeuristic: Equatable {
    case needsLogin
    case sessionReady
    case shouldProbeOpodo
    case shouldProbeTraveloka
    case shouldProbeBilligerMietwagen
    case shouldProbeCheck24
    case unknown
}

public enum ProviderSessionStatusResolver {
    /// Classifies based on URL host/path markers via `AuthPageURLHeuristic`
    /// and provider applicability via session probes.
    public static func classify(_ url: URL) -> ProviderSessionStatusHeuristic {
        let absolute = url.absoluteString.lowercased()
        let looksLikeLogin = AuthPageURLHeuristic.looksLikeLoginPage(absolute)
        let looksLikeAccount = AuthPageURLHeuristic.looksLikeAccountPage(absolute)

        // billiger-mietwagen: SPA bleibt oft auf /login während Buchungen sichtbar sind.
        // session.php ist die einzige verlässliche Session-Quelle (auch auf der Login-URL).
        if BilligerMietwagenSessionProbe.applies(to: url) {
            return .shouldProbeBilligerMietwagen
        }

        // Opodo: /travel/secure/ sieht aus wie Account, Session nur per GraphQL.
        if OpodoSessionProbe.applies(to: url) {
            return .shouldProbeOpodo
        }

        if looksLikeAccount && !looksLikeLogin {
            return .sessionReady
        } else if looksLikeLogin {
            return .needsLogin
        } else if Check24SessionProbe.applies(to: url) {
            // Nach SSO oft Marketing-Homepage (weder Login noch Account) → Activities-Probe.
            return .shouldProbeCheck24
        } else if TravelokaSessionProbe.applies(to: url) {
            return .shouldProbeTraveloka
        } else {
            return .unknown
        }
    }
}
