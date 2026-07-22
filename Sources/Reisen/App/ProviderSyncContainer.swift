import SwiftUI
import WebKit
import ReisenDomain
import ReisenProviders

/// Zeigt die Sync-UI des ausgewählten Providers.
/// Start: alle enabled Provider per Cookie/Session prüfen (1×1-Hosts), danach
/// entweder fertige Sessions anzeigen oder Login-Queue (erster needsLogin → Keychain/Auto-Login → nächster).
struct ProviderSyncContainer: View {
    @Binding var selectedProviderID: ProviderID

    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .check24))
    private var check24Enabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .opodo))
    private var opodoEnabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .booking))
    private var bookingEnabled: Bool
    @AppStorage(wrappedValue: true, AppSettingsKeys.providerEnabledKey(for: .airbnb))
    private var airbnbEnabled: Bool

    @Environment(\.providerSessionHub) private var hub
    @Environment(\.providerRegistry) private var providerRegistry

    private var enabledProviderIDs: [ProviderID] {
        var ids: [ProviderID] = []
        if check24Enabled { ids.append(.check24) }
        if opodoEnabled { ids.append(.opodo) }
        if bookingEnabled { ids.append(.booking) }
        if airbnbEnabled { ids.append(.airbnb) }
        return ids
    }

    private var enabledSet: Set<ProviderID> {
        Set(enabledProviderIDs)
    }

    private var isSelectedEnabled: Bool {
        enabledSet.contains(selectedProviderID)
    }

    private enum StartupPhase {
        case probing
        case ready
    }

    @State private var phase: StartupPhase = .probing
    @State private var backgroundProviderID: ProviderID?
    @State private var didBootstrap = false
    /// Hintergrundprobes nach Start der Login-UI abgeschlossen.
    @State private var didFinishBackgroundProbingRemaining = false
    /// Verhindert doppelte Startup-Bootstraps (z. B. bei SwiftUI-Re-appear).
    @State private var isRunningStartupBootstrap = false
    /// Provider, die nach Cookie-Probe noch Login brauchen (Reihenfolge = enabled-Liste).
    @State private var loginQueue: [ProviderID] = []
    @State private var isRunningLoginQueue = false
    @State private var probingProviderLabel: String = ""

    var body: some View {
        ZStack(alignment: .topLeading) {
            switch phase {
            case .probing:
                VStack(spacing: 12) {
                    ProgressView()
                        .controlSize(.regular)
                    Text("Provider-Sitzungen prüfen…")
                        .font(.headline)
                    if !probingProviderLabel.isEmpty {
                        Text(probingProviderLabel)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            case .ready:
                if isSelectedEnabled {
                    SyncView(providerID: selectedProviderID)
                        .id(selectedProviderID)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ContentUnavailableView(
                        "Provider deaktiviert",
                        systemImage: "nosign",
                        description: Text("Aktiviere den Provider über die Checkbox in der Seitenleiste.")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }

            // Unsichtbarer Probe-Host (nur während Bootstrap / ohne sichtbaren SyncView).
            if let backgroundProviderID {
                ProviderSessionView(
                    loginURL: providerLoginURL(for: backgroundProviderID),
                    sessionStatus: backgroundSessionStatusBinding(for: backgroundProviderID),
                    lastURLString: backgroundLastURLBinding(for: backgroundProviderID),
                    webView: backgroundWebViewBinding(for: backgroundProviderID),
                    autofillCredentials: nil,
                    rememberTrustedDeviceAutomatically: true
                )
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear { syncHub() }
        .onAppear {
            if hub?.didCompleteStartupProbe == true {
                phase = .ready
                let needingLogin = enabledProviderIDs.filter { hub?.status(for: $0) != .sessionReady }
                loginQueue = needingLogin
                if needingLogin.contains(selectedProviderID) {
                    isRunningLoginQueue = true
                }
                return
            }

            guard !isRunningStartupBootstrap else { return }
            didBootstrap = true
            isRunningStartupBootstrap = true

            Task { @MainActor in
                await runStartupBootstrapIncremental()
            }
        }
        .onChange(of: check24Enabled) { _, _ in syncHub() }
        .onChange(of: opodoEnabled) { _, _ in syncHub() }
        .onChange(of: bookingEnabled) { _, _ in syncHub() }
        .onChange(of: airbnbEnabled) { _, _ in syncHub() }
        .onChange(of: selectedHubStatus) { _, newStatus in
            guard phase == .ready, isRunningLoginQueue else { return }
            guard newStatus == .sessionReady else { return }
            advanceLoginQueueIfNeeded(completed: selectedProviderID)
        }
    }

    /// Beobachtet Hub-Status des sichtbaren Providers (für Login-Queue).
    private var selectedHubStatus: ProviderSessionStatus? {
        hub?.status(for: selectedProviderID)
    }

    private func syncHub() {
        hub?.syncEnabledProviders(enabledSet)
    }

    private func providerLoginURL(for providerID: ProviderID) -> URL? {
        guard let provider = providerRegistry?.provider(id: providerID),
              let loginConfig = provider as? TravelProviderLoginConfiguration else { return nil }
        return loginConfig.loginURL
    }

    private func backgroundSessionStatusBinding(for providerID: ProviderID) -> Binding<ProviderSessionStatus> {
        Binding(
            get: { hub?.status(for: providerID) ?? .needsLogin },
            set: { newValue in
                hub?.updateStatus(providerID, status: newValue)
            }
        )
    }

    private func backgroundLastURLBinding(for providerID: ProviderID) -> Binding<String?> {
        Binding(
            get: { hub?.lastURLString(for: providerID) },
            set: { newValue in
                hub?.updateLastURL(providerID, urlString: newValue)
            }
        )
    }

    private func backgroundWebViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
        Binding(
            get: { hub?.webView(for: providerID) },
            set: { newValue in
                hub?.updateWebView(providerID, webView: newValue)
            }
        )
    }

    /// Startup inkrementell: sobald der erste Provider gefunden ist, der noch Login braucht,
    /// wechseln wir sofort in die Login-UI. Die restlichen Provider werden im Hintergrund fertig geprüft.
    private func runStartupBootstrapIncremental() async {
        isRunningStartupBootstrap = true
        syncHub()
        phase = .probing
        backgroundProviderID = nil
        loginQueue = []
        isRunningLoginQueue = false
        didFinishBackgroundProbingRemaining = false

        AgentDebugLog.write(
            hypothesisId: "BOOT",
            location: "ProviderSyncContainer.swift:runStartupBootstrapIncremental",
            message: "start cookie/session probe incremental",
            data: [
                "enabledProviders": enabledProviderIDs.map(\.rawValue).joined(separator: ","),
            ]
        )

        var firstNeedingLoginIndex: Int?
        for (index, providerID) in enabledProviderIDs.enumerated() {
            probingProviderLabel = providerDisplayName(providerID)
            await probeProviderSession(providerID)

            if hub?.status(for: providerID) != .sessionReady {
                firstNeedingLoginIndex = index
                break
            }
        }

        probingProviderLabel = ""
        backgroundProviderID = nil

        // Alle ready: direkt bereit ohne Login-Queue.
        guard let firstNeedingLoginIndex else {
            if !enabledSet.contains(selectedProviderID), let first = enabledProviderIDs.first {
                selectedProviderID = first
            }
            isRunningLoginQueue = false
            didFinishBackgroundProbingRemaining = true
            hub?.markStartupProbeCompleted()
            phase = .ready
            isRunningStartupBootstrap = false
            return
        }

        // Sofortige Login-UI für den ersten needsLogin-Provider.
        let firstNeedingLogin = enabledProviderIDs[firstNeedingLoginIndex]
        selectedProviderID = firstNeedingLogin
        loginQueue = [firstNeedingLogin]
        isRunningLoginQueue = true
        phase = .ready

        // Restliche Provider im Hintergrund prüfen.
        let remainingStart = firstNeedingLoginIndex + 1
        Task { @MainActor in
            await probeRemainingProviders(startingAt: remainingStart)
        }
    }

    /// Läuft parallel zur sichtbaren Login-UI.
    @MainActor
    private func probeRemainingProviders(startingAt startIndex: Int) async {
        guard startIndex < enabledProviderIDs.count else {
            didFinishBackgroundProbingRemaining = true
            hub?.markStartupProbeCompleted()
            isRunningLoginQueue = !loginQueue.isEmpty
            isRunningStartupBootstrap = false
            return
        }

        for providerID in enabledProviderIDs[startIndex...] {
            // Der sichtbare Provider wird vom SyncView gehostet: Hintergrund darf ihn nicht übernehmen.
            if providerID == selectedProviderID { continue }

            probingProviderLabel = providerDisplayName(providerID)
            await probeProviderSession(providerID)
            probingProviderLabel = ""

            guard hub?.status(for: providerID) != .sessionReady else { continue }
            if !loginQueue.contains(providerID) {
                loginQueue.append(providerID)
            }

            // Wenn der User gerade schon fertig ist (current == sessionReady), zum nächsten springen.
            if isRunningLoginQueue,
               hub?.status(for: selectedProviderID) == .sessionReady,
               let next = loginQueue.first,
               next != selectedProviderID {
                selectedProviderID = next
            }
        }

        didFinishBackgroundProbingRemaining = true
        hub?.markStartupProbeCompleted()

        // Wenn Queue fertig ergänzt wurde und current bereits sessionReady ist, zum nächsten.
        if let next = loginQueue.first,
           hub?.status(for: selectedProviderID) == .sessionReady,
           next != selectedProviderID {
            selectedProviderID = next
        } else if loginQueue.isEmpty {
            isRunningLoginQueue = false
        }
        isRunningStartupBootstrap = false
    }

    /// Lädt Provider in 1×1-Host und wartet auf Cookie-Heuristik / Session-Probe.
    private func probeProviderSession(_ providerID: ProviderID) async {
        guard providerLoginURL(for: providerID) != nil else {
            AgentDebugLog.write(
                hypothesisId: "BOOT",
                location: "ProviderSyncContainer.swift:probeProviderSession",
                message: "skip no loginURL",
                data: ["provider": providerID.rawValue]
            )
            return
        }

        if hub?.status(for: providerID) == .sessionReady {
            AgentDebugLog.write(
                hypothesisId: "BOOT",
                location: "ProviderSyncContainer.swift:probeProviderSession",
                message: "already sessionReady",
                data: ["provider": providerID.rawValue]
            )
            return
        }

        backgroundProviderID = providerID
        AgentDebugLog.write(
            hypothesisId: "BOOT",
            location: "ProviderSyncContainer.swift:probeProviderSession",
            message: "probe start",
            data: ["provider": providerID.rawValue]
        )

        let timeoutNanoseconds: UInt64 = 5_000_000_000
        let pollNanoseconds: UInt64 = 200_000_000
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if hub?.status(for: providerID) == .sessionReady {
                break
            }

            let url = (hub?.lastURLString(for: providerID) ?? "").lowercased()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            if !url.isEmpty {
                let looksLogin = AuthPageURLHeuristic.looksLikeLoginPage(url)
                let looksAccount = AuthPageURLHeuristic.looksLikeAccountPage(url)
                // Login-Seite stabil → Cookies helfen nicht; Probe beenden.
                if looksLogin, elapsed >= 2_000_000_000 {
                    break
                }
                // Account-URL ohne Login → Status sollte gleich sessionReady setzen.
                if looksAccount, !looksLogin, elapsed >= 800_000_000 {
                    if hub?.status(for: providerID) == .sessionReady { break }
                }
                // Opodo-Homepage: GraphQL-Probe braucht ~0.5s nach didFinish.
                if !looksLogin, !looksAccount, elapsed >= 2_500_000_000 {
                    break
                }
            }

            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }

        backgroundProviderID = nil
        // Kurz warten, damit dismantle den Host freigibt, bevor der nächste startet.
        try? await Task.sleep(nanoseconds: 50_000_000)

        AgentDebugLog.write(
            hypothesisId: "BOOT",
            location: "ProviderSyncContainer.swift:probeProviderSession",
            message: "probe done",
            data: [
                "provider": providerID.rawValue,
                "status": String(describing: hub?.status(for: providerID)),
                "url": hub?.lastURLString(for: providerID) ?? "nil",
            ]
        )
    }

    private func advanceLoginQueueIfNeeded(completed providerID: ProviderID) {
        guard isRunningLoginQueue else { return }
        loginQueue.removeAll { $0 == providerID }

        AgentDebugLog.write(
            hypothesisId: "BOOT",
            location: "ProviderSyncContainer.swift:advanceLoginQueueIfNeeded",
            message: "login queue advance",
            data: [
                "completed": providerID.rawValue,
                "remaining": loginQueue.map(\.rawValue).joined(separator: ","),
            ]
        )

        if let next = loginQueue.first {
            if selectedProviderID != next {
                selectedProviderID = next
            }
        } else {
            // Warten, bis die Hintergrundprobes weitere needsLogin-Provider gefunden haben.
            isRunningLoginQueue = !didFinishBackgroundProbingRemaining
        }
    }

    private func providerDisplayName(_ providerID: ProviderID) -> String {
        switch providerID {
        case .check24: return "Check24"
        case .opodo: return "Opodo"
        case .booking: return "Booking.com"
        case .airbnb: return "Airbnb"
        default: return providerID.rawValue
        }
    }
}
