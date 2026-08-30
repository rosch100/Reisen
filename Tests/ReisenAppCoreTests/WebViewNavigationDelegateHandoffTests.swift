import Testing
import WebKit
@testable import ReisenAppCore

@MainActor
private final class SessionNavigationDelegate: NSObject, WKNavigationDelegate {}

@MainActor
private final class CancelNavigationDelegate: NSObject, WKNavigationDelegate {}

@MainActor
private final class ForeignNavigationDelegate: NSObject, WKNavigationDelegate {}

@Test @MainActor func webViewNavigationDelegateHandoff_restoresPreviousWhenOwnerStillSet() {
    let webView = WKWebView()
    let session = SessionNavigationDelegate()
    let cancel = CancelNavigationDelegate()
    webView.navigationDelegate = session

    let previous = WebViewNavigationDelegateHandoff.take(webView, owner: cancel)
    #expect(webView.navigationDelegate as AnyObject? === cancel)
    #expect(previous as AnyObject? === session)

    WebViewNavigationDelegateHandoff.release(webView, owner: cancel, previous: previous)
    #expect(webView.navigationDelegate as AnyObject? === session)
}

@Test @MainActor func webViewNavigationDelegateHandoff_doesNotOverwriteForeignDelegate() {
    let webView = WKWebView()
    let session = SessionNavigationDelegate()
    let cancel = CancelNavigationDelegate()
    let foreign = ForeignNavigationDelegate()
    webView.navigationDelegate = session

    let previous = WebViewNavigationDelegateHandoff.take(webView, owner: cancel)
    webView.navigationDelegate = foreign

    WebViewNavigationDelegateHandoff.release(webView, owner: cancel, previous: previous)
    #expect(webView.navigationDelegate as AnyObject? === foreign)
}

@Test @MainActor func webViewNavigationDelegateHandoff_releaseWithoutWebViewIsNoOp() {
    let cancel = CancelNavigationDelegate()
    let session = SessionNavigationDelegate()
    WebViewNavigationDelegateHandoff.release(nil, owner: cancel, previous: session)
}
