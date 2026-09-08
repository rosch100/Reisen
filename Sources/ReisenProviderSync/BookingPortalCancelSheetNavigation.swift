import Foundation
import WebKit
import ReisenAppCore
import ReisenDomain
import ReisenProviders

/// Shared cancel-sheet WK navigation: assist, completion probe, policy, handoff restore.
@MainActor
public final class BookingPortalCancelSheetNavigation: NSObject, WKNavigationDelegate {
    public var providerID: ProviderID
    public var onLoadFailed: () -> Void
    public var onCompletionDetected: () -> Void
    public var loadedURL: URL?
    public let cancelAssist = BookingPortalCancelAssistRouter()
    private weak var observedWebView: WKWebView?
    private var previousNavigationDelegate: (any WKNavigationDelegate)?

    public init(
        providerID: ProviderID,
        onLoadFailed: @escaping () -> Void,
        onCompletionDetected: @escaping () -> Void
    ) {
        self.providerID = providerID
        self.onLoadFailed = onLoadFailed
        self.onCompletionDetected = onCompletionDetected
    }

    public func adopt(_ webView: WKWebView) {
        if observedWebView === webView { return }
        releaseNavigationDelegate()
        previousNavigationDelegate = WebViewNavigationDelegateHandoff.take(webView, owner: self)
        observedWebView = webView
    }

    public func releaseNavigationDelegate() {
        cancelAssist.reset()
        WebViewNavigationDelegateHandoff.release(
            observedWebView,
            owner: self,
            previous: previousNavigationDelegate
        )
        previousNavigationDelegate = nil
        observedWebView = nil
    }

    /// Wires completion callback and loads `url` when it differs from the last load.
    public func prepareLoad(url: URL) {
        guard loadedURL != url, let webView = observedWebView else {
            cancelAssist.onPortalCancelCompleted = onCompletionDetected
            return
        }
        loadedURL = url
        cancelAssist.reset()
        cancelAssist.onPortalCancelCompleted = onCompletionDetected
        webView.load(URLRequest(url: url))
    }

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        cancelAssist.webViewDidFinish(webView, provider: providerID)
        PortalCancelCompletionProbe.evaluateIfNeeded(
            webView: webView,
            provider: providerID,
            onDetected: onCompletionDetected
        )
    }

    public func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        onLoadFailed()
    }

    public func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        onLoadFailed()
    }

    public func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(
            ProviderWebViewNavigationPolicy.navigationActionPolicy(
                url: navigationAction.request.url,
                isMainFrame: navigationAction.targetFrame?.isMainFrame ?? false
            )
        )
    }
}
