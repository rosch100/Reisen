import SwiftUI
import WebKit
import ReisenAppCore
import ReisenDomain
import ReisenSharedUI
#if REISEN_PROVIDER_SYNC
import ReisenProviders
#endif

extension View {
    func bookingPortalCancelSheet(_ request: Binding<BookingPortalCancelRequest?>) -> some View {
        sheet(item: request) { item in
            BookingPortalCancelSheetHostIOS(request: item) {
                request.wrappedValue = nil
            }
        }
    }
}

struct BookingPortalCancelSheetHostIOS: View {
    let request: BookingPortalCancelRequest
    var onDismiss: () -> Void

    @Environment(\.providerSessionHub) private var hub
    @State private var loadFailed = false

    var body: some View {
        NavigationStack {
            BookingPortalCancelSheetChrome(loadFailed: loadFailed, onDismiss: dismiss) {
                CancelSessionWebHostIOS(
                    webView: hub?.webView(for: request.providerID),
                    url: request.url,
                    allowsEmbed: hub?.allowsEmbed(on: .cancelSheet) ?? false,
                    onLoadFailed: { loadFailed = true }
                )
            }
        }
        .onAppear {
            hub?.setWebViewDisplayOwner(.cancelSheet)
        }
        .onDisappear {
            hub?.setWebViewDisplayOwner(.syncHost)
        }
    }

    private func dismiss() {
        hub?.setWebViewDisplayOwner(.syncHost)
        onDismiss()
    }
}

private struct CancelSessionWebHostIOS: UIViewRepresentable {
    var webView: WKWebView?
    var url: URL
    var allowsEmbed: Bool
    var onLoadFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFailed: onLoadFailed)
    }

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        embedIfNeeded(in: host, context: context)
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        context.coordinator.onLoadFailed = onLoadFailed
        if allowsEmbed {
            embedIfNeeded(in: uiView, context: context)
        }
    }

    static func dismantleUIView(_ uiView: UIView, coordinator: Coordinator) {
        coordinator.releaseNavigationDelegate()
    }

    private func embedIfNeeded(in host: UIView, context: Context) {
        guard allowsEmbed, let webView else { return }
        if webView.superview !== host {
            webView.removeFromSuperview()
            webView.translatesAutoresizingMaskIntoConstraints = false
            host.addSubview(webView)
            NSLayoutConstraint.activate([
                webView.topAnchor.constraint(equalTo: host.topAnchor),
                webView.bottomAnchor.constraint(equalTo: host.bottomAnchor),
                webView.leadingAnchor.constraint(equalTo: host.leadingAnchor),
                webView.trailingAnchor.constraint(equalTo: host.trailingAnchor),
            ])
        }
        context.coordinator.adopt(webView)
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadFailed: () -> Void
        var loadedURL: URL?
        weak var observedWebView: WKWebView?
        private var previousNavigationDelegate: (any WKNavigationDelegate)?

        init(onLoadFailed: @escaping () -> Void) {
            self.onLoadFailed = onLoadFailed
        }

        func adopt(_ webView: WKWebView) {
            if observedWebView === webView { return }
            releaseNavigationDelegate()
            previousNavigationDelegate = WebViewNavigationDelegateHandoff.take(webView, owner: self)
            observedWebView = webView
        }

        func releaseNavigationDelegate() {
            WebViewNavigationDelegateHandoff.release(
                observedWebView,
                owner: self,
                previous: previousNavigationDelegate
            )
            previousNavigationDelegate = nil
            observedWebView = nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadFailed()
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: Error
        ) {
            onLoadFailed()
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            #if REISEN_PROVIDER_SYNC
            let isMain = navigationAction.targetFrame?.isMainFrame ?? false
            if let requestURL = navigationAction.request.url,
               !ProviderWebViewNavigationPolicy.allows(requestURL, isMainFrame: isMain) {
                decisionHandler(.cancel)
                return
            }
            #endif
            decisionHandler(.allow)
        }
    }
}
