import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct WebViewHost: View {
    let loginURL: URL?
    let providerID: ProviderID
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    var body: some View {
        ProviderSessionWebView(
            loginURL: loginURL,
            webView: $webView,
            onDidFinish: onDidFinish
        )
    }
}

#if canImport(UIKit)
import UIKit

struct ProviderSessionWebView: UIViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        context.coordinator.loadedLoginURL = loginURL
        if let loginURL { view.load(URLRequest(url: loginURL)) }
        return view
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        guard let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            uiView.load(URLRequest(url: loginURL))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: (WKWebView) -> Void
        var loadedLoginURL: URL?

        init(onDidFinish: @escaping (WKWebView) -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish(webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            // SSOT-ähnlich zu ProviderSessionView: Session-Heuristik auch bei Redirect/Commit aktualisieren.
            onDidFinish(webView)
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            // Wenn die Navigation scheitert, bleibt meist der aktuelle URL-Stand für eine Heuristik relevant.
            onDidFinish(webView)
        }
    }
}
#else
import AppKit

struct ProviderSessionWebView: NSViewRepresentable {
    let loginURL: URL?
    @Binding var webView: WKWebView?
    let onDidFinish: (WKWebView) -> Void

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        let view = WKWebView(frame: .zero, configuration: configuration)
        view.navigationDelegate = context.coordinator
        webView = view
        context.coordinator.loadedLoginURL = loginURL
        if let loginURL { view.load(URLRequest(url: loginURL)) }
        return view
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        guard let loginURL else { return }
        if context.coordinator.loadedLoginURL != loginURL {
            context.coordinator.loadedLoginURL = loginURL
            nsView.load(URLRequest(url: loginURL))
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(onDidFinish: onDidFinish)
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        let onDidFinish: (WKWebView) -> Void
        var loadedLoginURL: URL?

        init(onDidFinish: @escaping (WKWebView) -> Void) {
            self.onDidFinish = onDidFinish
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onDidFinish(webView)
        }
    }
}
#endif

