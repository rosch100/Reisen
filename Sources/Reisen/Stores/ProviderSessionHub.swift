import Foundation
import WebKit
import Observation
import ReisenDomain

/// App-weite Provider-Sessions (wie Browser-Tabs): Status + WebView pro aktiviertem Provider.
@MainActor
@Observable
final class ProviderSessionHub {
    struct Slot: Equatable {
        var status: ProviderSessionStatus = .needsLogin
        var lastURLString: String?
        /// Nicht in Equatable einbezogen (Identität der WebView).
        var webView: WKWebView?

        static func == (lhs: Slot, rhs: Slot) -> Bool {
            lhs.status == rhs.status && lhs.lastURLString == rhs.lastURLString
        }
    }

    private(set) var slots: [ProviderID: Slot] = [:]
    /// Einmalige Cookie-/Session-Probe beim App-Start abgeschlossen.
    private(set) var didCompleteStartupProbe = false

    func markStartupProbeCompleted() {
        didCompleteStartupProbe = true
    }

    func syncEnabledProviders(_ enabledIDs: Set<ProviderID>) {
        for id in slots.keys where !enabledIDs.contains(id) {
            slots[id] = nil
        }
        for id in enabledIDs where slots[id] == nil {
            slots[id] = Slot()
        }
    }

    func updateStatus(_ providerID: ProviderID, status: ProviderSessionStatus) {
        guard var slot = slots[providerID] else { return }
        slot.status = status
        slots[providerID] = slot
    }

    func updateLastURL(_ providerID: ProviderID, urlString: String?) {
        guard var slot = slots[providerID] else { return }
        slot.lastURLString = urlString
        slots[providerID] = slot
    }

    func updateWebView(_ providerID: ProviderID, webView: WKWebView?) {
        guard var slot = slots[providerID] else { return }
        slot.webView = webView
        slots[providerID] = slot
    }

    func isLoggedIn(for providerID: ProviderID) -> Bool? {
        guard let slot = slots[providerID] else { return nil }
        return slot.status == .sessionReady
    }

    func webView(for providerID: ProviderID) -> WKWebView? {
        slots[providerID]?.webView
    }

    func status(for providerID: ProviderID) -> ProviderSessionStatus? {
        slots[providerID]?.status
    }

    func lastURLString(for providerID: ProviderID) -> String? {
        slots[providerID]?.lastURLString
    }
}
