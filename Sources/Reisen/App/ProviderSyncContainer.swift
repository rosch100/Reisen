import SwiftUI
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenAppCore
import ReisenSharedUI
import ReisenProviderSync

/// Zeigt die Sync-UI des ausgewählten Providers.
/// Start: alle enabled Provider per Cookie/Session prüfen (1×1-Hosts), danach
/// entweder fertige Sessions anzeigen oder Login-Queue (erster needsLogin → Keychain/Auto-Login → nächster).
struct ProviderSyncContainer: View {
    @Binding var selectedProviderID: ProviderID

    @Environment(\.providerSessionHub) private var hub
    @Environment(\.providerRegistry) private var providerRegistry

    @State private var providerEnableEpoch = 0
    @State private var diagnosticRunID = UUID()

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
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
                    Text(L10n.string(.syncProviderSessionsChecking))
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
                        L10n.string(.loginStatusGray),
                        systemImage: "nosign",
                        description: Text(L10n.string(.syncProviderDisabledHint))
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .accessibilityIdentifier(UITestingIdentifiers.syncProviderDisabledEmpty)
                }
            }

            // Unsichtbarer Probe-Host (nur während Bootstrap / ohne sichtbaren SyncView).
            if let backgroundProviderID {
                ProviderSessionView(
                    providerID: backgroundProviderID,
                    loginURL: providerLoginURL(for: backgroundProviderID),
                    sessionStatus: backgroundSessionStatusBinding(for: backgroundProviderID),
                    lastURLString: backgroundLastURLBinding(for: backgroundProviderID),
                    webView: backgroundWebViewBinding(for: backgroundProviderID),
                    autofillCredentials: nil,
                    passwordAutofillAllowedHosts: passwordAutofillAllowedHosts(for: backgroundProviderID),
                    allowsEmbed: hub?.allowsEmbed(on: .probe) ?? false,
                    diagnosticContext: DiagnosticContext(
                        runID: diagnosticRunID,
                        providerID: backgroundProviderID,
                        operation: "startup_probe"
                    ),
                    sessionHub: hub
                )
                .id(backgroundProviderID)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier(UITestingIdentifiers.syncChrome)
        .onAppear { syncHub() }
        .onProviderEnabledChange(bump: $providerEnableEpoch) {
            pruneLoginQueueForEnabledProviders()
            syncHub()
        }
        .onAppear {
            if UITestingLaunch.isActive {
                phase = .ready
                return
            }
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

    private func passwordAutofillAllowedHosts(for providerID: ProviderID) -> [String] {
        guard let provider = providerRegistry?.provider(id: providerID),
              let loginConfig = provider as? TravelProviderLoginConfiguration else { return [] }
        return loginConfig.passwordAutofillAllowedHosts
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
    ///
    /// Enabled-Liste wird zu Beginn gesnapshotet; Auswahl nur über stabile Provider-IDs
    /// (kein Index in die live berechnete Liste nach `await` — OOB-Crash).
    private func runStartupBootstrapIncremental() async {
        diagnosticRunID = UUID()
        isRunningStartupBootstrap = true
        syncHub()
        phase = .probing
        backgroundProviderID = nil
        loginQueue = []
        isRunningLoginQueue = false
        didFinishBackgroundProbingRemaining = false

        let providersSnapshot = enabledProviderIDs
        var firstNeedingLogin: ProviderID?
        for providerID in providersSnapshot {
            probingProviderLabel = providerDisplayName(providerID)
            await probeProviderSession(
                providerID,
                context: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: providerID,
                    operation: "startup_probe"
                )
            )

            if hub?.status(for: providerID) != .sessionReady {
                firstNeedingLogin = providerID
                break
            }
        }

        probingProviderLabel = ""
        backgroundProviderID = nil

        // Alle ready: direkt bereit ohne Login-Queue.
        guard let firstNeedingLogin else {
            if !enabledSet.contains(selectedProviderID), let first = enabledProviderIDs.first {
                selectedProviderID = first
            }
            isRunningLoginQueue = false
            didFinishBackgroundProbingRemaining = true
            hub?.markStartupProbeCompleted()
            ProviderSessionNavigation.resetProbeTracking()
            await DiagnosticLogger.shared.flush()
            phase = .ready
            isRunningStartupBootstrap = false
            return
        }

        // Sofortige Login-UI für den ersten needsLogin-Provider (ID aus Snapshot, kein Re-Index).
        selectedProviderID = firstNeedingLogin
        loginQueue = [firstNeedingLogin]
        isRunningLoginQueue = true
        phase = .ready

        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: firstNeedingLogin,
                    operation: "startup_probe"
                ),
                component: "ProviderSyncContainer",
                phase: "bootstrap",
                event: "first_needing_login_selected",
                result: .succeeded,
                reason: "snapshot_provider_id"
            )
        )

        let remaining = ProviderStartupLoginSelection.remainingToProbe(
            providersInOrder: providersSnapshot,
            after: firstNeedingLogin,
            stillEnabled: enabledSet
        )
        Task { @MainActor in
            await probeRemainingProviders(remaining)
        }
    }

    /// Läuft parallel zur sichtbaren Login-UI.
    @MainActor
    private func probeRemainingProviders(_ remaining: [ProviderID]) async {
        guard !remaining.isEmpty else {
            didFinishBackgroundProbingRemaining = true
            hub?.markStartupProbeCompleted()
            ProviderSessionNavigation.resetProbeTracking()
            await DiagnosticLogger.shared.flush()
            isRunningLoginQueue = !loginQueue.isEmpty
            isRunningStartupBootstrap = false
            return
        }

        for providerID in remaining {
            // Der sichtbare Provider wird vom SyncView gehostet: Hintergrund darf ihn nicht übernehmen.
            if providerID == selectedProviderID { continue }
            // Während await kann der User den Provider deaktivieren.
            guard enabledSet.contains(providerID) else { continue }

            probingProviderLabel = providerDisplayName(providerID)
            await probeProviderSession(
                providerID,
                context: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: providerID,
                    operation: "startup_probe_remaining"
                )
            )
            probingProviderLabel = ""

            guard hub?.status(for: providerID) != .sessionReady else { continue }
            if !loginQueue.contains(providerID) {
                loginQueue.append(providerID)
            }

            // Wenn der User gerade schon fertig ist (current == sessionReady), zum nächsten springen.
            if isRunningLoginQueue,
               hub?.status(for: selectedProviderID) == .sessionReady,
               let next = ProviderStartupLoginSelection.nextAfterCompleting(
                   completed: selectedProviderID,
                   in: loginQueue,
                   stillEnabled: enabledSet
               ),
               next != selectedProviderID {
                selectedProviderID = next
            }
        }

        didFinishBackgroundProbingRemaining = true
        hub?.markStartupProbeCompleted()
        ProviderSessionNavigation.resetProbeTracking()
        await DiagnosticLogger.shared.flush()

        // Wenn Queue fertig ergänzt wurde und current bereits sessionReady ist, zum nächsten.
        if let next = ProviderStartupLoginSelection.nextAfterCompleting(
            completed: selectedProviderID,
            in: loginQueue,
            stillEnabled: enabledSet
        ),
           hub?.status(for: selectedProviderID) == .sessionReady,
           next != selectedProviderID {
            selectedProviderID = next
        } else if ProviderStartupLoginSelection.prunedQueue(loginQueue, stillEnabled: enabledSet).isEmpty {
            isRunningLoginQueue = false
        }
        isRunningStartupBootstrap = false
    }

    /// Lädt Provider in 1×1-Host und wartet auf Cookie-Heuristik / Session-Probe.
    private func probeProviderSession(
        _ providerID: ProviderID,
        context: DiagnosticContext? = nil
    ) async {
        guard providerLoginURL(for: providerID) != nil else {
            if let context {
                await recordProbeEvent(
                    context: context,
                    event: "missing_login_url",
                    result: .skipped,
                    reason: "login_url_missing"
                )
            }
            return
        }

        if hub?.status(for: providerID) == .sessionReady {
            if let context {
                await recordProbeEvent(
                    context: context,
                    event: "already_ready",
                    result: .skipped
                )
            }
            return
        }

        backgroundProviderID = providerID
        let statusBefore = hub?.status(for: providerID)
        let start = DispatchTime.now().uptimeNanoseconds
        if let context {
            await recordProbeEvent(
                context: context,
                event: "started",
                result: .started,
                url: hub?.lastURLString(for: providerID),
                statusBefore: statusBefore
            )
        }

        let timeoutNanoseconds: UInt64 = 5_000_000_000
        let pollNanoseconds: UInt64 = 200_000_000

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if Task.isCancelled {
                backgroundProviderID = nil
                if let context {
                    await recordProbeEvent(
                        context: context,
                        event: "cancelled",
                        result: .cancelled,
                        reason: "task_cancelled",
                        url: hub?.lastURLString(for: providerID),
                        statusBefore: statusBefore,
                        statusAfter: hub?.status(for: providerID)
                    )
                }
                return
            }
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

            do {
                try await Task.sleep(nanoseconds: pollNanoseconds)
            } catch {
                backgroundProviderID = nil
                if let context {
                    await recordProbeEvent(
                        context: context,
                        event: "cancelled",
                        result: .cancelled,
                        reason: "task_cancelled",
                        url: hub?.lastURLString(for: providerID),
                        statusBefore: statusBefore,
                        statusAfter: hub?.status(for: providerID)
                    )
                }
                return
            }
        }

        backgroundProviderID = nil
        if let context {
            let elapsedMilliseconds = Int(
                (DispatchTime.now().uptimeNanoseconds - start) / 1_000_000
            )
            let ready = hub?.status(for: providerID) == .sessionReady
            await recordProbeEvent(
                context: context,
                event: ready ? "completed" : "timeout",
                result: ready ? .succeeded : .timedOut,
                durationMilliseconds: elapsedMilliseconds,
                reason: ready ? nil : "startup_probe_deadline",
                url: hub?.lastURLString(for: providerID),
                statusBefore: statusBefore,
                statusAfter: hub?.status(for: providerID)
            )
        }
        // Kurz warten, damit dismantle den Host freigibt, bevor der nächste startet.
        try? await Task.sleep(nanoseconds: 50_000_000)

    }

    private func recordProbeEvent(
        context: DiagnosticContext,
        event: String,
        result: DiagnosticResult,
        durationMilliseconds: Int? = nil,
        reason: String? = nil,
        url: String? = nil,
        statusBefore: ProviderSessionStatus? = nil,
        statusAfter: ProviderSessionStatus? = nil
    ) async {
        // URL roh; Host-Redaction ist SSOT in `DiagnosticLogger`.
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "ProviderSyncContainer",
                phase: "session_probe",
                event: event,
                result: result,
                durationMilliseconds: durationMilliseconds,
                url: url,
                reason: reason,
                statusBefore: statusBefore.map(String.init(describing:)),
                statusAfter: statusAfter.map(String.init(describing:))
            )
        )
    }

    private func advanceLoginQueueIfNeeded(completed providerID: ProviderID) {
        guard isRunningLoginQueue else { return }
        let next = ProviderStartupLoginSelection.nextAfterCompleting(
            completed: providerID,
            in: loginQueue,
            stillEnabled: enabledSet
        )
        loginQueue = ProviderStartupLoginSelection.prunedQueue(loginQueue, stillEnabled: enabledSet)
            .filter { $0 != providerID }

        if let next {
            if selectedProviderID != next {
                selectedProviderID = next
            }
            return
        }

        // Warten, bis die Hintergrundprobes weitere needsLogin-Provider gefunden haben.
        isRunningLoginQueue = !didFinishBackgroundProbingRemaining
        if selectedProviderID != providerID,
           !enabledSet.contains(selectedProviderID),
           enabledSet.contains(providerID) {
            selectedProviderID = providerID
        }
    }

    /// Enable-Toggle/Prefs: deaktivierte IDs aus der Queue nehmen, Fokus nicht auf Disabled belassen.
    private func pruneLoginQueueForEnabledProviders() {
        let before = loginQueue
        loginQueue = ProviderStartupLoginSelection.prunedQueue(loginQueue, stillEnabled: enabledSet)
        if loginQueue.isEmpty, didFinishBackgroundProbingRemaining {
            isRunningLoginQueue = false
        }
        if !enabledSet.contains(selectedProviderID), let first = enabledProviderIDs.first {
            selectedProviderID = first
        }
        let dropped = before.filter { !loginQueue.contains($0) }
        guard let firstDropped = dropped.first else { return }
        Task {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: DiagnosticContext(
                        runID: diagnosticRunID,
                        providerID: firstDropped,
                        operation: "login_queue_prune"
                    ),
                    component: "ProviderSyncContainer",
                    phase: "login_queue",
                    event: "disabled_providers_pruned",
                    result: .succeeded,
                    reason: "count_\(dropped.count)"
                )
            )
        }
    }

    private func providerDisplayName(_ providerID: ProviderID) -> String {
        providerRegistry?.provider(id: providerID)?.displayName ?? providerID.displayName
    }
}
