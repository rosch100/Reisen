import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct GlobalChromeTrailingToolbar: View {
    /// Nur für Re-Render bei Hub-Änderungen aus Hintergrund-Probes / SyncTab.
    @Binding var sessionChromeEpoch: Int

    @Environment(\.providerEnableEpoch) private var providerEnableEpoch
    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerSessionHub) private var sessionHub
    @Environment(\.providerRegistry) private var providerRegistry

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
    }

    private var syncAllCandidates: [(ProviderID, WKWebView)] {
        _ = sessionChromeEpoch
        guard let hub = sessionHub else { return [] }
        return SyncAllCoordinator.candidates(
            enabledProviderIDs: enabledProviderIDs,
            sessionHub: hub
        )
    }

    private var canStartSyncAll: Bool {
        guard let syncStore else { return false }
        guard syncStore.isSyncing != true else { return false }
        return !syncAllCandidates.isEmpty
    }

    var body: some View {
        Button {
            guard let syncStore, let sessionHub else { return }
            let runID = UUID()
            Task {
                await SyncAllCoordinator.run(
                    syncStore: syncStore,
                    enabledProviderIDs: enabledProviderIDs,
                    sessionHub: sessionHub,
                    settings: .fromUserDefaults(),
                    navigationHints: { id in
                        NavigationHintURLs.ordered(hubURLString: sessionHub.lastURLString(for: id))
                    },
                    diagnosticRunID: runID
                )
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
    @State private var diagnosticRunID = UUID()

    @Environment(\.providerEnableEpoch) private var providerEnableEpoch
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
    }

    private func loginURL(for providerID: ProviderID) -> URL? {
        let provider = providerRegistry?.provider(id: providerID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }

    private func passwordAutofillAllowedHosts(for providerID: ProviderID) -> [String] {
        let provider = providerRegistry?.provider(id: providerID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.passwordAutofillAllowedHosts ?? []
    }

    private func webViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
        Binding(
            get: { sessionHub?.webView(for: providerID) },
            set: { sessionHub?.updateWebView(providerID, webView: $0) }
        )
    }

    @MainActor
    private func ensureSlots() {
        sessionHub?.syncEnabledProviders(Set(enabledProviderIDs))
    }

    @MainActor
    private func handleWebNavigationDidFinish(providerID: ProviderID, _ finishedWebView: WKWebView) {
        guard let hub = sessionHub else { return }
        ProviderSessionNavigation.handleDidFinish(
            webView: finishedWebView,
            providerID: providerID,
            hub: hub,
            enabledProviderIDs: Set(enabledProviderIDs),
            notifyAlways: false,
            diagnosticContext: DiagnosticContext(
                runID: diagnosticRunID,
                providerID: providerID,
                operation: "ios_startup_probe"
            )
        ) {
            onSessionChanged()
        }
    }

    var body: some View {
        ZStack {
            ForEach(enabledProviderIDs, id: \.self) { id in
                WebViewHost(
                    loginURL: loginURL(for: id),
                    providerID: id,
                    diagnosticContext: DiagnosticContext(
                        runID: diagnosticRunID,
                        providerID: id,
                        operation: "ios_startup_probe"
                    ),
                    passwordAutofillAllowedHosts: passwordAutofillAllowedHosts(for: id),
                    webView: webViewBinding(for: id),
                    allowsEmbed: sessionHub?.allowsEmbed(on: .probe) ?? false,
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
        .onChange(of: enabledProviderIDs) { _, _ in
            ensureSlots()
        }
        .task {
            ensureSlots()
        }
    }
}

