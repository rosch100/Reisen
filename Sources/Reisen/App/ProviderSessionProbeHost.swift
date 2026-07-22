import SwiftUI
import WebKit
import ReisenDomain
import ReisenProviders

/// Unsichtbarer App-Start-Probe: prüft Cookies/Sessions aller enabled Provider.
/// Ruft `onFinished` mit den Providern auf, die noch Login brauchen.
struct ProviderSessionProbeHost: View {
    var onFinished: ([ProviderID]) -> Void

    init(onFinished: @escaping ([ProviderID]) -> Void) {
        self.onFinished = onFinished
    }

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

    @State private var backgroundProviderID: ProviderID?
    @State private var didStart = false

    private var enabledProviderIDs: [ProviderID] {
        var ids: [ProviderID] = []
        if check24Enabled { ids.append(.check24) }
        if opodoEnabled { ids.append(.opodo) }
        if bookingEnabled { ids.append(.booking) }
        if airbnbEnabled { ids.append(.airbnb) }
        return ids
    }

    var body: some View {
        ZStack {
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
            }

            // ZStack muss "echte" View-Hierarchie erzeugen, damit SwiftUI Lifecycle/Tasks zuverlässig feuern.
            Color.clear
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
        hub?.syncEnabledProviders(Set(enabledProviderIDs))

        for providerID in enabledProviderIDs {
            await probe(providerID)
        }

        backgroundProviderID = nil
        hub?.markStartupProbeCompleted()
        let needingLogin = enabledProviderIDs.filter { hub?.status(for: $0) != .sessionReady }
        onFinished(needingLogin)
    }

    private func probe(_ providerID: ProviderID) async {
        guard providerLoginURL(for: providerID) != nil else { return }
        if hub?.status(for: providerID) == .sessionReady { return }

        backgroundProviderID = providerID

        let timeoutNanoseconds: UInt64 = 5_000_000_000
        let pollNanoseconds: UInt64 = 200_000_000
        let start = DispatchTime.now().uptimeNanoseconds

        while DispatchTime.now().uptimeNanoseconds - start < timeoutNanoseconds {
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
            try? await Task.sleep(nanoseconds: pollNanoseconds)
        }

        backgroundProviderID = nil
        try? await Task.sleep(nanoseconds: 50_000_000)
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
