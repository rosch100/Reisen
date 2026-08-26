import Foundation

@MainActor
public enum NavigationSettleLoop {
    public static func wait(
        webView: NavigationWebView,
        targetHost: String,
        targetPath: String,
        deadline: Date,
        timeoutURL: URL
    ) async throws {
        var sawLoading = webView.isLoading

        while Date() < deadline {
            if try await NavigationSettlePoll.tick(
                webView: webView,
                targetHost: targetHost,
                targetPath: targetPath,
                sawLoading: &sawLoading
            ) {
                return
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        throw NavigationSettleTimeout.error(for: timeoutURL)
    }
}
