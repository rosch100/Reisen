import Foundation
import WebKit

import ReisenAppCore
import ReisenDomain
import ReisenProviders

/// Gemeinsame Pipeline: Navigation finished → Heuristik → Hub-Update → Session-Probe.
@MainActor
public enum ProviderSessionNavigation {
    public static func handleDidFinish(
        webView: WKWebView,
        providerID: ProviderID,
        hub: ProviderSessionHub,
        enabledProviderIDs: Set<ProviderID>? = nil,
        notifyAlways: Bool = false,
        diagnosticContext: DiagnosticContext,
        onChanged: @escaping () -> Void
    ) {
        record(
            context: diagnosticContext,
            phase: "navigation",
            event: "did_finish",
            result: .started,
            url: webView.url
        )
        if let enabledProviderIDs {
            hub.syncEnabledProviders(enabledProviderIDs)
        }
        let url = webView.url
            ?? hub.lastURLString(for: providerID).flatMap(URL.init(string:))
        guard let url else { return }

        let currentStatus = hub.status(for: providerID) ?? .needsLogin
        let previousReady = currentStatus == .sessionReady
        let heuristic = ProviderSessionStatusResolver.classify(url)
        record(
            context: diagnosticContext,
            phase: "session_status",
            event: "heuristic_classified",
            result: .succeeded,
            url: url,
            reason: String(describing: heuristic),
            statusBefore: String(describing: currentStatus),
            statusAfter: String(describing: currentStatus)
        )
        if let webViewURL = webView.url {
            hub.updateLastURL(providerID, urlString: webViewURL.absoluteString)
        }
        hub.updateWebView(providerID, webView: webView)

        if let status = immediateStatus(for: heuristic, current: currentStatus) {
            hub.updateStatus(providerID, status: status)
            record(
                context: diagnosticContext,
                phase: "session_status",
                event: "status_changed",
                result: .succeeded,
                reason: "heuristic",
                statusBefore: String(describing: currentStatus),
                statusAfter: String(describing: status)
            )
            if status != currentStatus {
                clearProbeStarts(for: providerID)
            }
        } else if let liveProbe = ProviderSessionLiveProbe.prepare(
            heuristic,
            sessionAlreadyReady: currentStatus == .sessionReady,
            url: url
        ) {
            startProbe(
                webView: webView,
                navigationURL: url,
                providerID: providerID,
                diagnosticContext: diagnosticContext,
                hub: hub,
                enabledProviderIDs: enabledProviderIDs,
                onChanged: onChanged,
                applies: liveProbe.applies
            ) { hints in
                try await ProviderSessionLiveProbe.fetchIsLoggedIn(
                    heuristic,
                    using: webView,
                    additionalHintURLs: hints
                )
            }
        }

        let nowReady = hub.status(for: providerID) == .sessionReady
        if notifyAlways || previousReady != nowReady || nowReady {
            onChanged()
        }
    }

    /// Sofortiger Hub-Status ohne Live-Probe. `nil` = Sticky belassen oder Probe starten.
    private static func immediateStatus(
        for heuristic: ProviderSessionStatusHeuristic,
        current: ProviderSessionStatus
    ) -> ProviderSessionStatus? {
        switch heuristic {
        case .sessionReady:
            return .sessionReady
        case .needsLogin:
            return .needsLogin
        case .unknown:
            return current == .sessionReady ? nil : .needsLogin
        case .shouldProbeOpodo, .shouldProbeTraveloka, .shouldProbeBilligerMietwagen, .shouldProbeCheck24:
            return nil
        }
    }

    private static func startProbe(
        webView: WKWebView,
        navigationURL: URL,
        providerID: ProviderID,
        diagnosticContext: DiagnosticContext,
        hub: ProviderSessionHub,
        enabledProviderIDs: Set<ProviderID>?,
        onChanged: @escaping () -> Void,
        applies: @escaping (URL) -> Bool,
        probe: @escaping @MainActor ([URL]) async throws -> Bool?
    ) {
        let probeStartCount = registerProbeStart(
            providerID: providerID,
            url: navigationURL
        )
        if probeStartCount >= 3 {
            record(
                context: diagnosticContext,
                phase: "session_probe",
                event: "repeated_probe",
                result: .failed,
                attempt: probeStartCount,
                url: navigationURL,
                reason: "identical_probe_starts"
            )
        }
        Task {
            let hints = hintURLs(hub: hub, providerID: providerID)
            guard hasProbeContext(
                webView: webView,
                navigationURL: navigationURL,
                hints: hints,
                applies: applies
            ) else {
                await recordEvent(
                    context: diagnosticContext,
                    phase: "session_probe",
                    event: "missing_probe_context",
                    result: .skipped,
                    url: navigationURL,
                    reason: "url_not_applicable"
                )
                return
            }
            do {
                guard let loggedIn = try await probe(hints) else {
                    await recordEvent(
                        context: diagnosticContext,
                        phase: "session_probe",
                        event: "unknown",
                        result: .skipped,
                        url: navigationURL,
                        reason: "probe_returned_unknown"
                    )
                    return
                }
                let statusBeforeProbeResult = hub.status(for: providerID)
                await recordEvent(
                    context: diagnosticContext,
                    phase: "session_probe",
                    event: "completed",
                    result: .succeeded,
                    url: navigationURL,
                    reason: loggedIn ? "session_ready" : "needs_login",
                    statusBefore: statusBeforeProbeResult.map { String(describing: $0) },
                    statusAfter: loggedIn ? "sessionReady" : "needsLogin"
                )
                applyProbeResult(
                    loggedIn: loggedIn,
                    providerID: providerID,
                    hub: hub,
                    enabledProviderIDs: enabledProviderIDs,
                    diagnosticContext: diagnosticContext,
                    onChanged: onChanged
                )
            } catch {
                let timedOut = NetworkErrorClassification.isURLTimeout(error)
                let cancelled = NetworkErrorClassification.isCancellation(error)
                let statusBeforeProbeFailure = hub.status(for: providerID)
                await recordEvent(
                    context: diagnosticContext,
                    phase: "session_probe",
                    event: cancelled ? "cancelled" : (timedOut ? "timeout" : "failed"),
                    result: cancelled ? .cancelled : (timedOut ? .timedOut : .failed),
                    url: navigationURL,
                    errorType: cancelled ? nil : String(reflecting: type(of: error)),
                    reason: cancelled
                        ? "task_cancelled"
                        : (timedOut
                            ? "probe_timeout"
                            : DiagnosticRedactor.redact(error.localizedDescription)),
                    statusBefore: statusBeforeProbeFailure.map { String(describing: $0) }
                )
            }
        }
    }

    private static func hintURLs(hub: ProviderSessionHub, providerID: ProviderID) -> [URL] {
        hub.lastURLString(for: providerID).flatMap(URL.init(string:)).map { [$0] } ?? []
    }

    private static func hasProbeContext(
        webView: WKWebView,
        navigationURL: URL,
        hints: [URL],
        applies: (URL) -> Bool
    ) -> Bool {
        [webView.url, navigationURL].compactMap { $0 }.contains(where: applies)
            || hints.contains(where: applies)
    }

    private static func applyProbeResult(
        loggedIn: Bool,
        providerID: ProviderID,
        hub: ProviderSessionHub,
        enabledProviderIDs: Set<ProviderID>?,
        diagnosticContext: DiagnosticContext,
        onChanged: @escaping () -> Void
    ) {
        let statusBefore = hub.status(for: providerID)
        if let enabledProviderIDs {
            hub.syncEnabledProviders(enabledProviderIDs)
        }
        hub.updateStatus(providerID, status: .fromProbe(loggedIn: loggedIn))
        clearProbeStarts(for: providerID)
        record(
            context: diagnosticContext,
            phase: "session_status",
            event: "status_changed",
            result: .succeeded,
            reason: loggedIn ? "session_ready" : "needs_login",
            statusBefore: statusBefore.map { String(describing: $0) },
            statusAfter: loggedIn ? "sessionReady" : "needsLogin"
        )
        onChanged()
    }

    /// URL roh übergeben; Host-Redaction ist SSOT in `DiagnosticLogger`.
    private static func record(
        context: DiagnosticContext,
        phase: String,
        event: String,
        result: DiagnosticResult,
        attempt: Int? = nil,
        url: URL? = nil,
        errorType: String? = nil,
        reason: String? = nil,
        statusBefore: String? = nil,
        statusAfter: String? = nil
    ) {
        Task {
            await recordEvent(
                context: context,
                phase: phase,
                event: event,
                result: result,
                attempt: attempt,
                url: url,
                errorType: errorType,
                reason: reason,
                statusBefore: statusBefore,
                statusAfter: statusAfter
            )
        }
    }

    private static func recordEvent(
        context: DiagnosticContext,
        phase: String,
        event: String,
        result: DiagnosticResult,
        attempt: Int? = nil,
        url: URL? = nil,
        errorType: String? = nil,
        reason: String? = nil,
        statusBefore: String? = nil,
        statusAfter: String? = nil
    ) async {
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: context,
                component: "ProviderSessionNavigation",
                phase: phase,
                event: event,
                result: result,
                attempt: attempt,
                url: url?.absoluteString,
                errorType: errorType,
                reason: reason,
                statusBefore: statusBefore,
                statusAfter: statusAfter
            )
        )
    }

    private static var probeStartTracker = ProbeStartTracker()

    private static func registerProbeStart(providerID: ProviderID, url: URL) -> Int {
        probeStartTracker.register(providerID: providerID, url: url, at: Date())
    }

    private static func clearProbeStarts(for providerID: ProviderID) {
        probeStartTracker.clear(providerID: providerID)
    }

    public static func resetProbeTracking() {
        probeStartTracker.reset()
    }

}

struct ProbeStartTracker {
    private static let window: TimeInterval = 10
    private var starts: [Key: State] = [:]
    private var lastURLByProvider: [ProviderID: String?] = [:]

    mutating func register(providerID: ProviderID, url: URL, at date: Date) -> Int {
        // Host+Pfad: nicht DiagnosticRedactor.urlMetadata (nur Host würde Pfade zusammenführen).
        let urlIdentity = navigationIdentity(for: url)
        if let previousURL = lastURLByProvider[providerID],
           previousURL != urlIdentity {
            clear(providerID: providerID)
        }
        lastURLByProvider[providerID] = urlIdentity
        let key = Key(providerID: providerID, url: urlIdentity)
        guard let previous = starts[key],
              date.timeIntervalSince(previous.startedAt) <= Self.window
        else {
            starts[key] = State(startedAt: date, count: 1)
            return 1
        }
        let count = previous.count + 1
        starts[key] = State(startedAt: previous.startedAt, count: count)
        return count
    }

    mutating func clear(providerID: ProviderID) {
        starts = starts.filter { $0.key.providerID != providerID }
        lastURLByProvider.removeValue(forKey: providerID)
    }

    mutating func reset() {
        starts.removeAll()
        lastURLByProvider.removeAll()
    }

    private func navigationIdentity(for url: URL) -> String? {
        guard let host = url.host, !host.isEmpty else { return nil }
        let path = url.path.isEmpty ? "/" : url.path
        return "\(host.lowercased())\(path)"
    }

    private struct Key: Hashable {
        let providerID: ProviderID
        let url: String?
    }

    private struct State {
        let startedAt: Date
        let count: Int
    }
}
