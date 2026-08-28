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
        onChanged: @escaping () -> Void
    ) {
        if let enabledProviderIDs {
            hub.syncEnabledProviders(enabledProviderIDs)
        }
        let url = webView.url
            ?? hub.lastURLString(for: providerID).flatMap(URL.init(string:))
        guard let url else { return }

        let currentStatus = hub.status(for: providerID) ?? .needsLogin
        let previousReady = currentStatus == .sessionReady
        let heuristic = ProviderSessionStatusResolver.classify(url)
        if let webViewURL = webView.url {
            hub.updateLastURL(providerID, urlString: webViewURL.absoluteString)
        }
        hub.updateWebView(providerID, webView: webView)

        if let status = immediateStatus(for: heuristic, current: currentStatus) {
            hub.updateStatus(providerID, status: status)
        } else {
            switch heuristic {
            case .shouldProbeOpodo:
                startProbe(
                    webView: webView,
                    navigationURL: url,
                    providerID: providerID,
                    hub: hub,
                    enabledProviderIDs: enabledProviderIDs,
                    onChanged: onChanged,
                    applies: OpodoSessionProbe.applies(to:)
                ) { _ in
                    let text = try await webView.fetchAuthenticatedText(
                        url: OpodoSessionProbe.graphqlURL,
                        method: "POST",
                        accept: "application/json",
                        referer: "https://www.opodo.de/",
                        contentType: "application/json",
                        body: OpodoSessionProbe.getUserAccountRequestBody()
                    )
                    return OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: text)
                }
            case .shouldProbeTraveloka:
                startProbe(
                    webView: webView,
                    navigationURL: url,
                    providerID: providerID,
                    hub: hub,
                    enabledProviderIDs: enabledProviderIDs,
                    onChanged: onChanged,
                    applies: TravelokaSessionProbe.applies(to:)
                ) { hints in
                    let context = await webView.travelokaSessionContext(additionalHintURLs: hints)
                    guard context.hasSentinel else { return nil }
                    let text = try await webView.fetchAuthenticatedText(
                        url: TravelokaSessionProbe.whoamiURL,
                        method: "POST",
                        accept: "application/json",
                        referer: context.apiReferer(),
                        contentType: "application/json",
                        body: try TravelokaSessionProbe.whoamiRequestBody(context: context),
                        headers: TravelokaSessionProbe.whoamiHeaders(context: context)
                    )
                    return TravelokaSessionProbe.isLoggedIn(fromWhoAmIJSON: text)
                }
            case .shouldProbeBilligerMietwagen:
                startProbe(
                    webView: webView,
                    navigationURL: url,
                    providerID: providerID,
                    hub: hub,
                    enabledProviderIDs: enabledProviderIDs,
                    onChanged: onChanged,
                    applies: BilligerMietwagenSessionProbe.applies(to:)
                ) { _ in
                    try await BilligerMietwagenSessionProbe.fetchIsLoggedIn(using: webView)
                }
            case .sessionReady, .needsLogin, .unknown:
                break
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
        case .shouldProbeOpodo, .shouldProbeTraveloka, .shouldProbeBilligerMietwagen:
            return nil
        }
    }

    private static func startProbe(
        webView: WKWebView,
        navigationURL: URL,
        providerID: ProviderID,
        hub: ProviderSessionHub,
        enabledProviderIDs: Set<ProviderID>?,
        onChanged: @escaping () -> Void,
        applies: @escaping (URL) -> Bool,
        probe: @escaping ([URL]) async throws -> Bool?
    ) {
        Task {
            let hints = hintURLs(hub: hub, providerID: providerID)
            guard hasProbeContext(
                webView: webView,
                navigationURL: navigationURL,
                hints: hints,
                applies: applies
            ) else {
                return
            }
            do {
                guard let loggedIn = try await probe(hints) else { return }
                applyProbeResult(
                    loggedIn: loggedIn,
                    providerID: providerID,
                    hub: hub,
                    enabledProviderIDs: enabledProviderIDs,
                    onChanged: onChanged
                )
            } catch {
                // Probe fehlgeschlagen: Status bleibt konservativ.
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
        onChanged: @escaping () -> Void
    ) {
        if let enabledProviderIDs {
            hub.syncEnabledProviders(enabledProviderIDs)
        }
        hub.updateStatus(providerID, status: .fromProbe(loggedIn: loggedIn))
        onChanged()
    }
}
