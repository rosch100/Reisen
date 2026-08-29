import Foundation
import ReisenDomain

/// Pfad-Hilfen für `NavigationPathMatching` (SSOT-Fassade).
public enum NavigationPathComponents {
    /// `shorter` ist Prefix von `longer` nur bei Gleichheit oder `shorter/`-Grenze; Root `/` nie.
    public static func isPathPrefix(_ shorter: String, of longer: String) -> Bool {
        if shorter == "/" || longer == "/" { return false }
        return PathPrefix.isUnder(longer, root: shorter)
    }

    public static func lastSignificantComponent(_ path: String) -> String? {
        NavigationPathTailComponent.lastSignificantComponent(path)
    }
}
