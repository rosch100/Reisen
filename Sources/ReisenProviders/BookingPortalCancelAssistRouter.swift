import Foundation
import WebKit
import ReisenDomain

/// Dispatches provider-specific cancel-sheet assists (BM, Opodo).
@MainActor
public final class BookingPortalCancelAssistRouter {
    private let billigerMietwagen = BilligerMietwagenCancelAssistRunner()
    private let opodo = OpodoCancelAssistRunner()

    /// Portal cancel completion seen by Assist (Opodo already-cancelled).
    public var onPortalCancelCompleted: (() -> Void)? {
        didSet { opodo.onAlreadyCancelled = onPortalCancelCompleted }
    }

    public init() {}

    public func reset() {
        billigerMietwagen.reset()
        opodo.reset()
    }

    public func webViewDidFinish(_ webView: WKWebView, provider: ProviderID) {
        opodo.onAlreadyCancelled = onPortalCancelCompleted
        billigerMietwagen.webViewDidFinish(webView, provider: provider)
        opodo.webViewDidFinish(webView, provider: provider)
    }
}
