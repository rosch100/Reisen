import Foundation

@MainActor
public enum NavigationSettleReady {
    public static func isSettled(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool
    ) -> Bool {
        let onTarget = NavigationTargetMatching.isOnTarget(
            webView: webView,
            host: targetHost,
            path: targetPath
        )
        return onTarget && !webView.isLoading && (sawLoading || webView.url != nil)
    }
}
