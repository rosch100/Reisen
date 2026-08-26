import Foundation
import WebKit

/// SSOT: Keychain-Konto in Provider-WebView laden und ausfüllen.
public enum KeychainAutoFill {
    public static let webViewRetryCount = 10
    public static let webViewRetryDelayNanoseconds: UInt64 = 250_000_000
    public static let loginSettleDelayNanoseconds: UInt64 = 350_000_000

    @MainActor
    @discardableResult
    public static func applyAccount(
        _ account: KeychainCredentialAccount,
        in webView: WKWebView,
        store: KeychainCredentialStore = KeychainCredentialStore()
    ) throws -> ProviderCredentials {
        let credentials = try store.credentials(for: account)
        ProviderLoginAssistance.applyCredentials(in: webView, credentials: credentials)
        return credentials
    }

    /// Wartet bis WebView bereit ist oder Retries erschöpft sind.
    @MainActor
    public static func waitForWebView(
        retryCount: Int = webViewRetryCount,
        retryDelayNanoseconds: UInt64 = webViewRetryDelayNanoseconds,
        shouldContinue: () -> Bool,
        webView: () -> WKWebView?
    ) async -> WKWebView? {
        for _ in 0..<retryCount {
            guard shouldContinue() else { return nil }
            if let view = webView() { return view }
            try? await Task.sleep(nanoseconds: retryDelayNanoseconds)
        }
        return nil
    }

    /// Bevorzugtes Konto: explizit → gespeichert → einziges Konto.
    public static func pickAccount(
        from accounts: [KeychainCredentialAccount],
        storedPreferredID: String,
        explicitPreferred: KeychainCredentialAccount? = nil
    ) -> KeychainCredentialAccount? {
        guard !accounts.isEmpty else { return nil }

        if let explicitPreferred,
           accounts.contains(where: { $0.id == explicitPreferred.id }) {
            return explicitPreferred
        }

        if let stored = accounts.first(where: { $0.id == storedPreferredID }) {
            return stored
        }

        if accounts.count == 1 {
            return accounts[0]
        }

        return nil
    }

    @MainActor
    public static func runWhenWebViewReady(
        shouldContinue: @escaping @MainActor () -> Bool,
        webView: @escaping @MainActor () -> WKWebView?,
        action: @escaping @MainActor (WKWebView) -> Void
    ) async {
        guard let view = await waitForWebView(
            shouldContinue: shouldContinue,
            webView: webView
        ) else { return }
        action(view)
    }

    @MainActor
    public static func startWebViewReadyTask(
        existing: inout Task<Void, Never>?,
        shouldContinue: @escaping @MainActor () -> Bool,
        webView: @escaping @MainActor () -> WKWebView?,
        action: @escaping @MainActor (WKWebView) -> Void
    ) {
        existing?.cancel()
        existing = Task { @MainActor in
            await runWhenWebViewReady(
                shouldContinue: shouldContinue,
                webView: webView,
                action: action
            )
        }
    }
}
