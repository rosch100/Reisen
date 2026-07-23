import Foundation

/// Plattformneutrale Heuristik, ob eine Provider-Seite eher „Login erforderlich“,
/// „bereits angemeldet“ oder „Opodo GraphQL-Session-Probe nötig“ signalisiert.
///
/// Wichtig: Das hier ist nur die URL-Klassifikation. Cookie-/Session-Probing (Opodo)
/// passiert weiterhin in der jeweiligen Session-UI (macOS/iOS).
public enum ProviderSessionStatusHeuristic: Equatable {
    case needsLogin
    case sessionReady
    case shouldProbeOpodo
    case unknown
}

public enum ProviderSessionStatusResolver {
    /// Classifies based on URL host/path markers via `AuthPageURLHeuristic`
    /// and provider applicability via `OpodoSessionProbe`.
    public static func classify(_ url: URL) -> ProviderSessionStatusHeuristic {
        let absolute = url.absoluteString.lowercased()
        let looksLikeLogin = AuthPageURLHeuristic.looksLikeLoginPage(absolute)
        let looksLikeAccount = AuthPageURLHeuristic.looksLikeAccountPage(absolute)

        if looksLikeAccount && !looksLikeLogin {
            return .sessionReady
        } else if looksLikeLogin {
            return .needsLogin
        } else if OpodoSessionProbe.applies(to: url) {
            return .shouldProbeOpodo
        } else {
            return .unknown
        }
    }
}

