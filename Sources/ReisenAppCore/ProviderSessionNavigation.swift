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
        guard let url = webView.url else { return }

        let previousReady = hub.status(for: providerID) == .sessionReady
        let heuristic = ProviderSessionStatusResolver.classify(url)
        hub.updateLastURL(providerID, urlString: url.absoluteString)
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
                do {
                    let context = await webView.travelokaSessionContext()
                    guard context.hasSentinel else { return }
                    let text = try await webView.fetchAuthenticatedText(
                        url: TravelokaSessionProbe.whoamiURL,
                        method: "POST",
                        accept: "application/json",
                        referer: TravelokaSessionProbe.signInReferer(routePrefix: context.routePrefix),
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
        case .shouldProbeTraveloka:
            Task {
                do {
                    let context = await webView.travelokaSessionContext()
                    guard context.hasSentinel else { return }
                    let text = try await webView.fetchAuthenticatedText(
                        url: TravelokaSessionProbe.whoamiURL,
                        method: "POST",
                        accept: "application/json",
                        referer: TravelokaSessionProbe.signInReferer(routePrefix: context.routePrefix),
                        contentType: "application/json",
                        body: try TravelokaSessionProbe.whoamiRequestBody(context: context),
                        headers: TravelokaSessionProbe.whoamiHeaders(context: context)
                    )
                    if let loggedIn = TravelokaSessionProbe.isLoggedIn(fromWhoAmIJSON: text) {
                        await MainActor.run {
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
