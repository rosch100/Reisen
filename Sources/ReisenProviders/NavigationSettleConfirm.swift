import Foundation

@MainActor
public enum NavigationSettleConfirm {
    public static func tryConfirm(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool
    ) async throws -> Bool {
        guard NavigationSettleReady.isSettled(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            sawLoading: sawLoading
        ) else {
            return false
        }
        try await Task.sleep(nanoseconds: 350_000_000)
        return !webView.isLoading
    }
}
