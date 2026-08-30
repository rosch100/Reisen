import WebKit

/// Übernimmt und gibt `WKWebView.navigationDelegate` zurück, ohne einen fremden Owner zu überschreiben.
@MainActor
public enum WebViewNavigationDelegateHandoff {
    public static func take(
        _ webView: WKWebView,
        owner: any WKNavigationDelegate
    ) -> (any WKNavigationDelegate)? {
        let previous = webView.navigationDelegate
        webView.navigationDelegate = owner
        return previous
    }

    public static func release(
        _ webView: WKWebView?,
        owner: any WKNavigationDelegate,
        previous: (any WKNavigationDelegate)?
    ) {
        guard let webView else { return }
        guard webView.navigationDelegate as AnyObject? === owner as AnyObject else { return }
        webView.navigationDelegate = previous
    }
}
