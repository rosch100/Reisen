import Foundation

/// Host/Pfad-Vergleich für Navigation-Settle (SSOT-Fassade).
public enum NavigationTargetMatching {
    public static func normalizedPath(_ path: String) -> String {
        NavigationPathNormalize.normalizedPath(path)
    }

    public static func hostsMatch(_ a: String, _ b: String) -> Bool {
        NavigationHostMatching.hostsMatch(a, b)
    }

    @MainActor
    public static func isOnTarget(webView: NavigationWebView, host: String, path: String) -> Bool {
        guard let current = webView.url else { return false }
        let currentHost = (current.host ?? "").lowercased()
        guard hostsMatch(currentHost, host) else { return false }
        return NavigationPathMatching.pathsMatch(
            currentPath: normalizedPath(current.path),
            targetPath: path
        )
    }
}
