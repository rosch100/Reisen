import Foundation

/// App-übergreifender Status der Provider-Session (Login/ready).
public enum ProviderSessionStatus: Equatable {
    case needsLogin
    case sessionReady

    /// Auswertbares Probe-Ergebnis (`nil`/Fehler ändert den Status nicht — Caller entscheidet).
    public static func fromProbe(loggedIn: Bool) -> ProviderSessionStatus {
        loggedIn ? .sessionReady : .needsLogin
    }
}
