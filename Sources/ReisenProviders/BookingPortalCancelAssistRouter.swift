import Foundation
import WebKit
import ReisenDomain

/// Dispatches provider-specific cancel-sheet assists (BM, Opodo, Expedia Car).
@MainActor
public final class BookingPortalCancelAssistRouter {
    private let billigerMietwagen = BilligerMietwagenCancelAssistRunner()
    private let opodo = OpodoCancelAssistRunner()
    private let expediaCar = ExpediaCarCancelAssistRunner()

    /// Portal cancel completion seen by Assist (Opodo already-cancelled).
    public var onPortalCancelCompleted: (() -> Void)? {
        didSet { opodo.onAlreadyCancelled = onPortalCancelCompleted }
    }

    public init() {}

    public func reset() {
        billigerMietwagen.reset()
        opodo.reset()
        expediaCar.reset()
    }

    public func webViewDidFinish(
        _ webView: WKWebView,
        provider: ProviderID,
        bookingType: BookingType? = nil
    ) {
        opodo.onAlreadyCancelled = onPortalCancelCompleted
        billigerMietwagen.webViewDidFinish(webView, provider: provider)
        opodo.webViewDidFinish(webView, provider: provider)
        expediaCar.webViewDidFinish(webView, provider: provider, bookingType: bookingType)
    }
}
