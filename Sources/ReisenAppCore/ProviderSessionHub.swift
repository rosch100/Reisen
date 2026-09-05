import Foundation
import WebKit
import Observation
import ReisenDomain
import ReisenData

/// App-weit gültiger Provider-Session-Status (wie „Browser-Tabs“): Status + WKWebView pro aktivem Provider.
@MainActor
@Observable
public final class ProviderSessionHub {
    public struct Slot: Equatable {
        public var status: ProviderSessionStatus = .needsLogin
        public var lastURLString: String?
        /// Letzte bewusst angeforderte Login-URL (überlebt SwiftUI-Coordinator-Remount).
        public var requestedLoginURL: URL?
        /// Nicht in Equatable einbezogen: Identität der WebView.
        public var webView: WKWebView?

        public init(
            status: ProviderSessionStatus = .needsLogin,
            lastURLString: String? = nil,
            requestedLoginURL: URL? = nil,
            webView: WKWebView? = nil
        ) {
            self.status = status
            self.lastURLString = lastURLString
            self.requestedLoginURL = requestedLoginURL
            self.webView = webView
        }

        public static func == (lhs: Slot, rhs: Slot) -> Bool {
            lhs.status == rhs.status
                && lhs.lastURLString == rhs.lastURLString
                && lhs.requestedLoginURL == rhs.requestedLoginURL
        }
    }

    private(set) public var slots: [ProviderID: Slot] = [:]
    /// Einmalige Cookie-/Session-Probe beim App-Start abgeschlossen.
    private(set) public var didCompleteStartupProbe = false
    public private(set) var webViewDisplayOwner: ProviderWebViewDisplayOwner = .syncHost

    public init() {}

    public func setWebViewDisplayOwner(_ owner: ProviderWebViewDisplayOwner) {
        webViewDisplayOwner = owner
    }

    public func allowsEmbed(on host: ProviderWebViewHostRole) -> Bool {
        ProviderWebViewDisplayPolicy.allowsEmbed(owner: webViewDisplayOwner, host: host)
    }

    public func markStartupProbeCompleted() {
        didCompleteStartupProbe = true
    }

    public func syncEnabledProviders(_ enabledIDs: Set<ProviderID>) {
        for id in slots.keys where !enabledIDs.contains(id) {
            slots[id] = nil
        }
        for id in enabledIDs where slots[id] == nil {
            slots[id] = Slot()
        }
    }

    public func updateStatus(_ providerID: ProviderID, status: ProviderSessionStatus) {
        guard var slot = slots[providerID] else { return }
        slot.status = status
        slots[providerID] = slot
    }

    public func updateLastURL(_ providerID: ProviderID, urlString: String?) {
        guard var slot = slots[providerID] else { return }
        slot.lastURLString = urlString
        slots[providerID] = slot
    }

    public func updateWebView(_ providerID: ProviderID, webView: WKWebView?) {
        guard var slot = slots[providerID] else { return }
        slot.webView = webView
        if webView == nil {
            slot.requestedLoginURL = nil
        }
        slots[providerID] = slot
    }

    /// Merkt die Login-URL am Slot, damit Remounts mit neuem Coordinator nicht neu laden.
    public func noteRequestedLoginURL(_ providerID: ProviderID, url: URL) {
        guard var slot = slots[providerID] else { return }
        slot.requestedLoginURL = url
        slots[providerID] = slot
    }

    public func requestedLoginURL(for providerID: ProviderID) -> URL? {
        slots[providerID]?.requestedLoginURL
    }

    /// SSOT gegen SwiftUI-Remount-Churn: create nur wenn der Slot noch keine WebView hat.
    /// - Returns: bestehende oder neu erzeugte WebView; `nil` wenn der Provider keinen Slot hat.
    @discardableResult
    public func ensureWebView(
        _ providerID: ProviderID,
        create: () -> WKWebView
    ) -> WKWebView? {
        guard slots[providerID] != nil else { return nil }
        if let existing = slots[providerID]?.webView {
            return existing
        }
        let created = create()
        updateWebView(providerID, webView: created)
        return created
    }

    public func isLoggedIn(for providerID: ProviderID) -> Bool? {
        guard let slot = slots[providerID] else { return nil }
        return slot.status == .sessionReady
    }

    public func webView(for providerID: ProviderID) -> WKWebView? {
        slots[providerID]?.webView
    }

    public func hasSessionWebView(for providerID: ProviderID) -> Bool {
        guard let slot = slots[providerID] else { return false }
        return slot.webView != nil && slot.status == .sessionReady
    }

    public func hasSessionWebView(for booking: SDBooking) -> Bool {
        hasSessionWebView(for: booking.provider)
    }

    public func status(for providerID: ProviderID) -> ProviderSessionStatus? {
        slots[providerID]?.status
    }

    public func lastURLString(for providerID: ProviderID) -> String? {
        slots[providerID]?.lastURLString
    }
}

extension Optional where Wrapped == ProviderSessionHub {
    @MainActor
    public func hasSessionWebView(for booking: SDBooking) -> Bool {
        self?.hasSessionWebView(for: booking) ?? false
    }
}
