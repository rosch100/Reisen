import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct GlobalChromeTrailingToolbar: View {
    /// Nur für Re-Render bei Hub-Änderungen aus Hintergrund-Probes / SyncTab.
    @Binding var sessionChromeEpoch: Int

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerRegistry) private var providerRegistry

    private var syncProviderIDs: [ProviderID] {
        providerRegistry?.syncProviderIDs ?? []
    }

    private var syncAllCandidates: [(ProviderID, WKWebView)] {
        _ = sessionChromeEpoch
        guard let hub = sessionHub else { return [] }
        return syncProviderIDs.compactMap { id in
            guard hub.status(for: id) == .sessionReady,
                  let webView = hub.webView(for: id) else { return nil }
            return (id, webView)
        }
    }

    private var canStartSyncAll: Bool {
        guard let syncStore else { return false }
        guard syncStore.isSyncing != true else { return false }
        return !syncAllCandidates.isEmpty
    }

    var body: some View {
        Button {
            guard let syncStore else { return }
            let candidates = syncAllCandidates
            guard !candidates.isEmpty else { return }
            Task {
                await syncStore.syncAll(providers: candidates, settings: .fromUserDefaults())
            }
        } label: {
            if syncStore?.isSyncing == true && syncStore?.syncingProviderID != nil {
                ProgressView()
                    .controlSize(.small)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath")
            }
        }
        .disabled(!canStartSyncAll)
        .help(canStartSyncAll
            ? "Synchronisiert alle angemeldeten Provider (sequenziell) im Hintergrund"
            : "Keine angemeldeten Provider für Sync-All")
    }
}


struct SyncBackgroundSessionProbe: View {
    var onSessionChanged: () -> Void

    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub

    @State private var webViewsByProvider: [ProviderID: WKWebView?] = [:]

    private var syncProviderIDs: [ProviderID] {
        providerRegistry?.syncProviderIDs ?? []
    }

    private func loginURL(for providerID: ProviderID) -> URL? {
        let provider = providerRegistry?.provider(id: providerID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }

    private func webViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
        Binding(
            get: { webViewsByProvider[providerID] ?? nil },
            set: { webViewsByProvider[providerID] = $0 }
        )
    }

    @MainActor
    private func ensureSlots() {
        sessionHub?.syncEnabledProviders(Set(syncProviderIDs))
    }

    @MainActor
    private func handleWebNavigationDidFinish(providerID: ProviderID, _ finishedWebView: WKWebView) {
        guard let hub = sessionHub else { return }
        ProviderSessionNavigation.handleDidFinish(
            webView: finishedWebView,
            providerID: providerID,
            hub: hub,
            enabledProviderIDs: Set(syncProviderIDs),
            notifyAlways: false
        ) {
            onSessionChanged()
        }
    }

    var body: some View {
        ZStack {
            ForEach(syncProviderIDs, id: \.self) { id in
                WebViewHost(
                    loginURL: loginURL(for: id),
                    providerID: id,
                    webView: webViewBinding(for: id),
                    onDidFinish: { finishedWebView in
                        handleWebNavigationDidFinish(providerID: id, finishedWebView)
                    }
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .onAppear {
            ensureSlots()
        }
        .task {
            ensureSlots()
        }
    }
}

