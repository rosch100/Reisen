import Foundation

/// Pfad-Hilfen für `NavigationPathMatching` (SSOT-Fassade).
public enum NavigationPathComponents {
    public static func isPathPrefix(_ shorter: String, of longer: String) -> Bool {
        NavigationPathPrefix.isPathPrefix(shorter, of: longer)
    }

    public static func lastSignificantComponent(_ path: String) -> String? {
        NavigationPathTailComponent.lastSignificantComponent(path)
    }
}
