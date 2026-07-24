import Foundation
import WebKit
import Observation
import ReisenDomain

/// App-weit gültiger Provider-Session-Status (wie „Browser-Tabs“): Status + WKWebView pro aktivem Provider.
@MainActor
@Observable
public final class ProviderSessionHub {
    public struct Slot: Equatable {
        public var status: ProviderSessionStatus = .needsLogin
        public var lastURLString: String?
        /// Nicht in Equatable einbezogen: Identität der WebView.
        public var webView: WKWebView?

        public init(
            status: ProviderSessionStatus = .needsLogin,
            lastURLString: String? = nil,
            webView: WKWebView? = nil
        ) {
            self.status = status
            self.lastURLString = lastURLString
            self.webView = webView
        }

        public static func == (lhs: Slot, rhs: Slot) -> Bool {
            lhs.status == rhs.status && lhs.lastURLString == rhs.lastURLString
        }
    }

    private(set) public var slots: [ProviderID: Slot] = [:]
    /// Einmalige Cookie-/Session-Probe beim App-Start abgeschlossen.
    private(set) public var didCompleteStartupProbe = false

    public init() {}

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
        slots[providerID] = slot
    }

    public func isLoggedIn(for providerID: ProviderID) -> Bool? {
        guard let slot = slots[providerID] else { return nil }
        return slot.status == .sessionReady
    }

    public func webView(for providerID: ProviderID) -> WKWebView? {
        slots[providerID]?.webView
    }

    public func status(for providerID: ProviderID) -> ProviderSessionStatus? {
        slots[providerID]?.status
    }

    public func lastURLString(for providerID: ProviderID) -> String? {
        slots[providerID]?.lastURLString
    }
}

