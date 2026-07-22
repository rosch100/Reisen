import Foundation

/// Path-Vergleich für `NavigationAwaiter` (testbar, SSOT).
public enum NavigationPathMatching {
    public static func pathsMatch(currentPath: String, targetPath: String) -> Bool {
        if currentPath == targetPath { return true }

        // Prefix nur an Segmentgrenzen — sonst matcht "/" fälschlich jedes Ziel
        // (verifiziert: Opodo blieb auf www.opodo.de/ statt /travel/secure/#tripdetails).
        if isPathPrefix(currentPath, of: targetPath) || isPathPrefix(targetPath, of: currentPath) {
            return true
        }

        if let targetTail = lastSignificantComponent(targetPath) {
            if let currentTail = lastSignificantComponent(currentPath), currentTail == targetTail {
                return true
            }
            if currentPath.contains(targetTail) {
                return true
            }
        }
        return false
    }

    /// `shorter` ist Prefix von `longer` nur bei Gleichheit oder `shorter/`-Grenze; Root `/` nie.
    private static func isPathPrefix(_ shorter: String, of longer: String) -> Bool {
        if shorter == "/" || longer == "/" { return false }
        return longer == shorter || longer.hasPrefix(shorter + "/")
    }

    private static func lastSignificantComponent(_ path: String) -> String? {
        let parts = path.split(separator: "/").map(String.init).filter { !$0.isEmpty }
        guard let last = parts.last, last.count >= 8 else { return nil }
        return last
    }
}
