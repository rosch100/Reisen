import SwiftUI
import AppKit
import WebKit
import ReisenAppCore
import ReisenDomain
import ReisenProviderSync
import ReisenSharedUI

extension View {
    func bookingPortalCancelSheet(_ request: Binding<BookingPortalCancelRequest?>) -> some View {
        sheet(item: request) { item in
            BookingPortalCancelSheetHost(request: item) {
                request.wrappedValue = nil
            }
        }
    }
}

struct BookingPortalCancelSheetHost: View {
    let request: BookingPortalCancelRequest
    var onDismiss: () -> Void

    @Environment(\.providerSessionHub) private var hub
    @State private var loadFailed = false
    @State private var cancellationLikelyCompleted = false

    var body: some View {
        BookingPortalCancelSheetChrome(loadFailed: loadFailed, onDismiss: dismiss) {
            CancelSessionWebHost(
                webView: hub?.webView(for: request.providerID),
                providerID: request.providerID,
                url: request.url,
                allowsEmbed: hub?.allowsEmbed(on: .cancelSheet) ?? false,
                onLoadFailed: { loadFailed = true },
                onCompletionDetected: { cancellationLikelyCompleted = true }
            )
        }
        .frame(minWidth: 720, minHeight: 520)
        .onAppear {
            hub?.setWebViewDisplayOwner(.cancelSheet)
        }
        .onDisappear {
            hub?.setWebViewDisplayOwner(.syncHost)
            PortalCancelProviderResync.consumeCompletionAndRequest(
                &cancellationLikelyCompleted,
                providerID: request.providerID
            )
        }
    }

    private func dismiss() {
        hub?.setWebViewDisplayOwner(.syncHost)
        onDismiss()
    }
}

private struct CancelSessionWebHost: NSViewRepresentable {
    var webView: WKWebView?
    var providerID: ProviderID
    var url: URL
    var allowsEmbed: Bool
    var onLoadFailed: () -> Void
    var onCompletionDetected: () -> Void

    func makeCoordinator() -> BookingPortalCancelSheetNavigation {
        BookingPortalCancelSheetNavigation(
            providerID: providerID,
            onLoadFailed: onLoadFailed,
            onCompletionDetected: onCompletionDetected
        )
    }

    func makeNSView(context: Context) -> NSView {
        let host = NSView(frame: .zero)
        host.wantsLayer = true
        embedIfNeeded(in: host, context: context)
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        context.coordinator.onLoadFailed = onLoadFailed
        context.coordinator.onCompletionDetected = onCompletionDetected
        context.coordinator.providerID = providerID
        if allowsEmbed {
            embedIfNeeded(in: nsView, context: context)
        }
    }

    static func dismantleNSView(_ nsView: NSView, coordinator: BookingPortalCancelSheetNavigation) {
        coordinator.releaseNavigationDelegate()
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
        context.coordinator.adopt(webView)
        context.coordinator.prepareLoad(url: url)
    }
}
