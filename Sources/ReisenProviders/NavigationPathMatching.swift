import Foundation

/// Path-Vergleich für `NavigationAwaiter` (testbar, SSOT).
public enum NavigationPathMatching {
    public static func pathsMatch(currentPath: String, targetPath: String) -> Bool {
        if currentPath == targetPath { return true }

        // Prefix nur an Segmentgrenzen — sonst matcht "/" fälschlich jedes Ziel
        // (verifiziert: Opodo blieb auf www.opodo.de/ statt /travel/secure/#tripdetails).
        if NavigationPathComponents.isPathPrefix(currentPath, of: targetPath)
            || NavigationPathComponents.isPathPrefix(targetPath, of: currentPath) {
            return true
        }

        return NavigationPathTailMatching.tailsMatch(currentPath: currentPath, targetPath: targetPath)
    }
}
