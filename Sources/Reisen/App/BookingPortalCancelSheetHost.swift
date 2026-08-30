import SwiftUI
import AppKit
import WebKit
import ReisenAppCore
import ReisenDomain
import ReisenSharedUI

struct BookingPortalCancelSheetHost: View {
    let request: BookingPortalCancelRequest
    var onDismiss: () -> Void

    @Environment(\.providerSessionHub) private var hub
    @State private var loadFailed = false

    var body: some View {
        BookingPortalCancelSheetChrome(loadFailed: loadFailed, onDismiss: dismiss) {
            CancelSessionWebHost(
                webView: hub?.webView(for: request.providerID),
                url: request.url,
                allowsEmbed: hub?.allowsEmbed(on: .cancelSheet) ?? false,
                onLoadFailed: { loadFailed = true }
            )
        }
        .frame(minWidth: 720, minHeight: 520)
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

private struct CancelSessionWebHost: NSViewRepresentable {
    var webView: WKWebView?
    var url: URL
    var allowsEmbed: Bool
    var onLoadFailed: () -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onLoadFailed: onLoadFailed)
    }

    func makeNSView(context: Context) -> NSView {
        let host = NSView(frame: .zero)
        host.wantsLayer = true
        embedIfNeeded(in: host, context: context)
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onLoadFailed = onLoadFailed
        if allowsEmbed {
            embedIfNeeded(in: nsView, context: context)
        }
    }

    private func embedIfNeeded(in host: NSView, context: Context) {
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
        webView.navigationDelegate = context.coordinator
        if context.coordinator.loadedURL != url {
            context.coordinator.loadedURL = url
            webView.load(URLRequest(url: url))
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadFailed: () -> Void
        var loadedURL: URL?

        init(onLoadFailed: @escaping () -> Void) {
            self.onLoadFailed = onLoadFailed
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
    }
}
