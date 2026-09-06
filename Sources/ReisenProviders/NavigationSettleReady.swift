import Foundation

@MainActor
public enum NavigationSettleReady {
    public static let onTargetLoadingGrace: TimeInterval = 2.0

    public static func isSettled(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool,
        onTargetSince: Date? = nil,
        now: Date = Date()
    ) -> Bool {
        let onTarget = NavigationTargetMatching.isOnTarget(
            webView: webView,
            host: targetHost,
            path: targetPath
        )
        guard onTarget, sawLoading || webView.url != nil else { return false }
        if !webView.isLoading { return true }
        guard let since = onTargetSince else { return false }
        return now.timeIntervalSince(since) >= onTargetLoadingGrace
    }
}
