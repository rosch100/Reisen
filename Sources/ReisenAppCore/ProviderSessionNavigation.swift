import Foundation
import WebKit
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

        let previousReady = hub.status(for: providerID) == .sessionReady
        let heuristic = ProviderSessionStatusResolver.classify(url)
        if let webViewURL = webView.url {
            hub.updateLastURL(providerID, urlString: webViewURL.absoluteString)
        }
        hub.updateWebView(providerID, webView: webView)

        switch heuristic {
        case .sessionReady:
            hub.updateStatus(providerID, status: .sessionReady)
        case .needsLogin, .unknown:
            if hub.status(for: providerID) != .sessionReady {
                hub.updateStatus(providerID, status: .needsLogin)
            }
        case .shouldProbeOpodo:
            Task {
                let hintURLs = hub.lastURLString(for: providerID).flatMap(URL.init(string:)).map { [$0] } ?? []
                let hasOpodoContext = [webView.url, url].compactMap { $0 }.contains(where: OpodoSessionProbe.applies(to:))
                    || hintURLs.contains(where: OpodoSessionProbe.applies(to:))
                guard hasOpodoContext else { return }
                do {
                    let text = try await webView.fetchAuthenticatedText(
                        url: OpodoSessionProbe.graphqlURL,
                        method: "POST",
                        accept: "application/json",
                        referer: "https://www.opodo.de/",
                        contentType: "application/json",
                        body: OpodoSessionProbe.getUserAccountRequestBody()
                    )
                    if let loggedIn = OpodoSessionProbe.isLoggedIn(fromGraphQLJSON: text) {
                        await MainActor.run {
                            applyProbeResult(
                                loggedIn: loggedIn,
                                providerID: providerID,
                                hub: hub,
                                enabledProviderIDs: enabledProviderIDs,
                                onChanged: onChanged
                            )
                        }
                    }
                } catch {
                    // Probe fehlgeschlagen: Status bleibt konservativ.
                }
            }
        case .shouldProbeTraveloka:
            Task {
                let hintURLs = hub.lastURLString(for: providerID).flatMap(URL.init(string:)).map { [$0] } ?? []
                let hasTravelokaContext = [webView.url, url].compactMap { $0 }.contains(where: TravelokaSessionProbe.applies(to:))
                    || hintURLs.contains(where: TravelokaSessionProbe.applies(to:))
                guard hasTravelokaContext else { return }
                do {
                    let context = await webView.travelokaSessionContext(additionalHintURLs: hintURLs)
                    guard context.hasSentinel else { return }
                    let text = try await webView.fetchAuthenticatedText(
                        url: TravelokaSessionProbe.whoamiURL,
                        method: "POST",
                        accept: "application/json",
                        referer: context.apiReferer(),
                        contentType: "application/json",
                        body: try TravelokaSessionProbe.whoamiRequestBody(context: context),
                        headers: TravelokaSessionProbe.whoamiHeaders(context: context)
                    )
                    if let loggedIn = TravelokaSessionProbe.isLoggedIn(fromWhoAmIJSON: text) {
                        await MainActor.run {
                            applyProbeResult(
                                loggedIn: loggedIn,
                                providerID: providerID,
                                hub: hub,
                                enabledProviderIDs: enabledProviderIDs,
                                onChanged: onChanged
                            )
                        }
                    }
                } catch {
                    // Probe fehlgeschlagen: Status bleibt konservativ.
                }
            }
        }

        let nowReady = hub.status(for: providerID) == .sessionReady
        if notifyAlways || previousReady != nowReady || nowReady {
            onChanged()
        }
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
        if loggedIn {
            hub.updateStatus(providerID, status: .sessionReady)
        } else if hub.status(for: providerID) != .sessionReady {
            hub.updateStatus(providerID, status: .needsLogin)
        }
        onChanged()
    }
}
