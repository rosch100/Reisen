import Foundation

@MainActor
public enum NavigationSettleConfirm {
    private static let holdNanoseconds: UInt64 = 350_000_000

    public static func tryConfirm(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        sawLoading: Bool,
        onTargetSince: Date? = nil,
        now: Date = Date()
    ) async throws -> Bool {
        guard NavigationSettleReady.isSettled(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            sawLoading: sawLoading,
            onTargetSince: onTargetSince,
            now: now
        ) else {
            return false
        }
        try await Task.sleep(nanoseconds: holdNanoseconds)
        return NavigationSettleReady.isSettled(
            webView: webView,
            targetHost: targetHost,
            targetPath: targetPath,
            sawLoading: sawLoading,
            onTargetSince: onTargetSince,
            now: Date()
        )
    }
}
