import Foundation
import WebKit

import ReisenAppCore
import ReisenDomain
import ReisenProviders

/// SSOT für Sync-All-Kandidaten und sequenziellen Abruf (Mac + iOS Private).
@MainActor
public enum SyncAllCoordinator {
    public static func candidates(
        enabledProviderIDs: [ProviderID],
        sessionHub: ProviderSessionHub
    ) -> [(ProviderID, WKWebView)] {
        enabledProviderIDs.compactMap { id in
            guard sessionHub.status(for: id) == .sessionReady,
                  let webView = sessionHub.webView(for: id) else { return nil }
            return (id, webView)
        }
    }

    public static func run(
        syncStore: SyncStore,
        enabledProviderIDs: [ProviderID],
        sessionHub: ProviderSessionHub,
        settings: AppSettings,
        navigationHints: @escaping (ProviderID) -> [URL],
        diagnosticRunID: UUID
    ) async {
        let ready = candidates(
            enabledProviderIDs: enabledProviderIDs,
            sessionHub: sessionHub
        )
        guard !ready.isEmpty else { return }
        await syncStore.syncAll(
            providers: ready,
            settings: settings,
            resolveNavigationHintURLs: navigationHints,
            diagnosticRunID: diagnosticRunID
        )
    }
}
