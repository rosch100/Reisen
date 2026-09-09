import SwiftUI
import WebKit
import ReisenAppCore
import ReisenDomain
import ReisenSharedUI
#if REISEN_PROVIDER_SYNC
import ReisenProviderSync
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
    @State private var cancellationLikelyCompleted = false

    var body: some View {
        NavigationStack {
            BookingPortalCancelSheetChrome(loadFailed: loadFailed, onDismiss: dismiss) {
                CancelSessionWebHostIOS(
                    webView: hub?.webView(for: request.providerID),
                    providerID: request.providerID,
                    bookingType: request.bookingType,
                    url: request.url,
                    allowsEmbed: hub?.allowsEmbed(on: .cancelSheet) ?? false,
                    onLoadFailed: { loadFailed = true },
                    onCompletionDetected: { cancellationLikelyCompleted = true }
                )
            }
        }
        .onAppear {
            hub?.setWebViewDisplayOwner(.cancelSheet)
        }
        .onDisappear {
            hub?.setWebViewDisplayOwner(.syncHost)
            #if REISEN_PROVIDER_SYNC
            PortalCancelProviderResync.consumeCompletionAndRequest(
                &cancellationLikelyCompleted,
                providerID: request.providerID
            )
            #endif
        }
    }

    private func dismiss() {
        hub?.setWebViewDisplayOwner(.syncHost)
        onDismiss()
    }
}

private struct CancelSessionWebHostIOS: UIViewRepresentable {
    var webView: WKWebView?
    var providerID: ProviderID
    var bookingType: BookingType?
    var url: URL
    var allowsEmbed: Bool
    var onLoadFailed: () -> Void
    var onCompletionDetected: () -> Void

    #if REISEN_PROVIDER_SYNC
    func makeCoordinator() -> BookingPortalCancelSheetNavigation {
        BookingPortalCancelSheetNavigation(
            providerID: providerID,
            bookingType: bookingType,
            onLoadFailed: onLoadFailed,
            onCompletionDetected: onCompletionDetected
        )
    }
    #else
    func makeCoordinator() -> StoreCancelCoordinator {
        StoreCancelCoordinator(onLoadFailed: onLoadFailed)
    }
    #endif

    func makeUIView(context: Context) -> UIView {
        let host = UIView()
        embedIfNeeded(in: host, context: context)
        return host
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        #if REISEN_PROVIDER_SYNC
        context.coordinator.onLoadFailed = onLoadFailed
        context.coordinator.onCompletionDetected = onCompletionDetected
        context.coordinator.providerID = providerID
        context.coordinator.bookingType = bookingType
        #else
        context.coordinator.onLoadFailed = onLoadFailed
        #endif
        if allowsEmbed {
            embedIfNeeded(in: uiView, context: context)
        }
    }

    #if REISEN_PROVIDER_SYNC
    static func dismantleUIView(_ uiView: UIView, coordinator: BookingPortalCancelSheetNavigation) {
        coordinator.releaseNavigationDelegate()
    }
    #else
    static func dismantleUIView(_ uiView: UIView, coordinator: StoreCancelCoordinator) {
        coordinator.releaseNavigationDelegate()
    }
    #endif

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
        #if REISEN_PROVIDER_SYNC
        context.coordinator.adopt(webView)
        context.coordinator.prepareLoad(url: url)
        #else
        context.coordinator.adopt(webView)
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            webView.load(URLRequest(url: url))
        }
        #endif
    }
}

#if !REISEN_PROVIDER_SYNC
/// Store build: sheet loads URL without assist/resync (no ProviderSync).
private final class StoreCancelCoordinator: NSObject, WKNavigationDelegate {
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

    @MainActor
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping @MainActor (WKNavigationActionPolicy) -> Void
    ) {
        decisionHandler(.allow)
    }
}
#endif
