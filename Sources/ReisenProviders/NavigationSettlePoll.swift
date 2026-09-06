import Foundation

@MainActor
public enum NavigationSettlePoll {
    public static func tick(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: inout Bool,
        onTargetSince: Date? = nil
    ) async throws -> Bool {
        if webView.isLoading { sawLoading = true }
        return try await NavigationSettleConfirm.tryConfirm(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            sawLoading: sawLoading,
            onTargetSince: onTargetSince
        )
    }
}
