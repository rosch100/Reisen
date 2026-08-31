import SwiftUI
import WebKit
import ReisenDomain
import ReisenProviders
import ReisenAppCore
import ReisenSharedUI
import ReisenProviderSync

/// Unsichtbarer App-Start-Probe: prüft Cookies/Sessions aller enabled Provider.
/// Ruft `onFinished` mit den Providern auf, die noch Login brauchen.
struct ProviderSessionProbeHost: View {
    var onFinished: ([ProviderID]) -> Void

    init(onFinished: @escaping ([ProviderID]) -> Void) {
        self.onFinished = onFinished
    }

    @Environment(\.providerSessionHub) private var hub
    @Environment(\.providerRegistry) private var providerRegistry

    @State private var backgroundProviderID: ProviderID?
    @State private var diagnosticRunID = UUID()
    @State private var didStart = false
    @State private var providerEnableEpoch = 0

    private var enabledProviderIDs: [ProviderID] {
        _ = providerEnableEpoch
        return providerRegistry?.enabledSyncProviderIDs() ?? []
    }

    var body: some View {
        ZStack {
            if let backgroundProviderID {
                ProviderSessionView(
                    providerID: backgroundProviderID,
                    loginURL: providerLoginURL(for: backgroundProviderID),
                    sessionStatus: backgroundSessionStatusBinding(for: backgroundProviderID),
                    lastURLString: backgroundLastURLBinding(for: backgroundProviderID),
                    webView: backgroundWebViewBinding(for: backgroundProviderID),
                    autofillCredentials: nil,
                    allowsEmbed: hub?.allowsEmbed(on: .probe) ?? false,
                    diagnosticContext: DiagnosticContext(
                        runID: diagnosticRunID,
                        providerID: backgroundProviderID,
                        operation: "startup_probe"
                    )
                )
                .id(backgroundProviderID)
                .frame(width: 1, height: 1)
            }

            // ZStack muss "echte" View-Hierarchie erzeugen, damit SwiftUI Lifecycle/Tasks zuverlässig feuern.
            Color.clear
        }
        .onProviderEnabledChange(bump: $providerEnableEpoch) {
            hub?.syncEnabledProviders(Set(enabledProviderIDs))
        }
        .task {
            guard !didStart else { return }
            didStart = true

            if hub?.didCompleteStartupProbe == true {
                let needing = enabledProviderIDs.filter { hub?.status(for: $0) != .sessionReady }
                onFinished(needing)
                return
            }

            Task { @MainActor in
                await runProbe()
            }
        }
    }

    private func runProbe() async {
        diagnosticRunID = UUID()
        hub?.syncEnabledProviders(Set(enabledProviderIDs))

        for providerID in enabledProviderIDs {
            await probe(
                providerID,
                context: DiagnosticContext(
                    runID: diagnosticRunID,
                    providerID: providerID,
                    operation: "startup_probe"
                )
            )
        }

        ProviderSessionNavigation.resetProbeTracking()
        await DiagnosticLogger.shared.flush()
        backgroundProviderID = nil
        hub?.markStartupProbeCompleted()
        let needingLogin = enabledProviderIDs.filter { hub?.status(for: $0) != .sessionReady }
        onFinished(needingLogin)
    }

    private func probe(
        _ providerID: ProviderID,
        context: DiagnosticContext
    ) async {
        guard let loginURL = providerLoginURL(for: providerID) else {
            await recordProbeEvent(
                context: context,
                event: "missing_login_url",
                result: .skipped,
                reason: "source=provider_login_url"
            )
            return
        }
        let statusBefore = hub?.status(for: providerID)
        if hub?.status(for: providerID) == .sessionReady {
            await recordProbeEvent(
                context: context,
                event: "already_ready",
                result: .skipped,
                url: loginURL,
                reason: "source=provider_login_url",
                statusBefore: statusBefore,
                statusAfter: statusBefore
            )
            return
        }

        backgroundProviderID = providerID
        let startedAt = Date()
        await recordProbeEvent(
            context: context,
            event: "started",
            result: .started,
            url: loginURL,
            reason: "source=provider_login_url",
            statusBefore: statusBefore,
            statusAfter: nil
        )

        let timeoutNanoseconds: UInt64 = 5_000_000_000
        let pollNanoseconds: UInt64 = 200_000_000
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
            if Task.isCancelled {
                backgroundProviderID = nil
                await recordProbeEvent(
                    context: context,
                    event: "cancelled",
                    result: .cancelled,
                    url: currentURL(for: providerID),
                    durationMilliseconds: elapsedMilliseconds(since: startedAt),
                    reason: "source=provider_login_url",
                    statusBefore: statusBefore,
                    statusAfter: hub?.status(for: providerID)
                )
                return
            }
            if hub?.status(for: providerID) == .sessionReady { break }

            let url = (hub?.lastURLString(for: providerID) ?? "").lowercased()
            let elapsed = DispatchTime.now().uptimeNanoseconds - start
            if !url.isEmpty {
                let looksLogin = AuthPageURLHeuristic.looksLikeLoginPage(url)
                let looksAccount = AuthPageURLHeuristic.looksLikeAccountPage(url)
                if looksLogin, elapsed >= 2_000_000_000 { break }
                if looksAccount, !looksLogin, elapsed >= 800_000_000 {
                    if hub?.status(for: providerID) == .sessionReady { break }
                }
                if !looksLogin, !looksAccount, elapsed >= 2_500_000_000 { break }
            }
            do {
                try await Task.sleep(nanoseconds: pollNanoseconds)
            } catch {
                backgroundProviderID = nil
                await recordProbeEvent(
                    context: context,
                    event: "cancelled",
                    result: .cancelled,
                    url: currentURL(for: providerID),
                    durationMilliseconds: elapsedMilliseconds(since: startedAt),
                    reason: "source=provider_login_url",
                    statusBefore: statusBefore,
                    statusAfter: hub?.status(for: providerID)
                )
                return
            }
        }

        backgroundProviderID = nil
        let statusAfter = hub?.status(for: providerID)
        await recordProbeEvent(
            context: context,
            event: statusAfter == .sessionReady ? "completed" : "timeout",
            result: statusAfter == .sessionReady ? .succeeded : .timedOut,
            url: currentURL(for: providerID),
            durationMilliseconds: elapsedMilliseconds(since: startedAt),
            reason: "source=provider_login_url",
            statusBefore: statusBefore,
            statusAfter: statusAfter
        )
    }

    private func recordProbeEvent(
        context: DiagnosticContext,
        event: String,
        result: DiagnosticResult,
        url: URL? = nil,
        durationMilliseconds: Int? = nil,
        reason: String? = nil,
        statusBefore: ProviderSessionStatus? = nil,
        statusAfter: ProviderSessionStatus? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "ProviderSessionProbeHost",
                phase: "session_probe",
                event: event,
                result: result,
                durationMilliseconds: durationMilliseconds,
                url: url?.absoluteString,
                reason: reason,
                statusBefore: statusBefore.map { String(describing: $0) },
                statusAfter: statusAfter.map { String(describing: $0) }
            )
        )
    }

    private func currentURL(for providerID: ProviderID) -> URL? {
        hub?.lastURLString(for: providerID).flatMap(URL.init(string:))
    }

    private func elapsedMilliseconds(since start: Date) -> Int {
        Int(Date().timeIntervalSince(start) * 1_000)
    }

    private func providerLoginURL(for providerID: ProviderID) -> URL? {
        guard let provider = providerRegistry?.provider(id: providerID),
              let loginConfig = provider as? TravelProviderLoginConfiguration else { return nil }
        return loginConfig.loginURL
    }

    private func backgroundSessionStatusBinding(for providerID: ProviderID) -> Binding<ProviderSessionStatus> {
        Binding(
            get: { hub?.status(for: providerID) ?? .needsLogin },
            set: { hub?.updateStatus(providerID, status: $0) }
        )
    }

    private func backgroundLastURLBinding(for providerID: ProviderID) -> Binding<String?> {
        Binding(
            get: { hub?.lastURLString(for: providerID) },
            set: { hub?.updateLastURL(providerID, urlString: $0) }
        )
    }

    private func backgroundWebViewBinding(for providerID: ProviderID) -> Binding<WKWebView?> {
        Binding(
            get: { hub?.webView(for: providerID) },
            set: { hub?.updateWebView(providerID, webView: $0) }
        )
    }
}
