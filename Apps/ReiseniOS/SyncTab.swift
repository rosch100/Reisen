import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct SyncTab: View {
    @Binding var sessionChromeEpoch: Int

    @Environment(\.syncStore) private var syncStore
    @Environment(\.providerRegistry) private var providerRegistry
    @Environment(\.providerSessionHub) private var sessionHub

    @State private var selectedProviderID: ProviderID = .check24
    @State private var webView: WKWebView?
    @State private var showCreateTrip = false
    @State private var showCredentialSheet = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                providerPicker
                sessionBanner
                Divider()

                WebViewHost(
                    loginURL: loginURLForSelectedProvider(),
                    providerID: selectedProviderID,
                    webView: $webView,
                    onDidFinish: { finishedWebView in
                        handleWebDidFinish(finishedWebView)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                actionBar
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Sync")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateTrip = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .help("Neue Reise anlegen")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    GlobalChromeTrailingToolbar(sessionChromeEpoch: $sessionChromeEpoch)
                }
            }
            .sheet(isPresented: $showCreateTrip) {
                TripEditorSheet(mode: .create, onSaved: { _ in })
                .reisenSheetDetents()
            }
            .sheet(isPresented: $showCredentialSheet) {
                if let host = credentialServerHost() {
                    SaveProviderCredentialSheet(serverHost: host) { _ in
                        showCredentialSheet = false
                    }
                }
            }
            .onAppear {
                guard let sessionHub else { return }
                sessionHub.syncEnabledProviders(Set(iosSyncProviderIDs))
            }
            .onChange(of: selectedProviderID) { _, newProviderID in
                guard let sessionHub else { return }
                if sessionHub.status(for: newProviderID) != .sessionReady {
                    sessionHub.updateStatus(newProviderID, status: .needsLogin)
                }
            }
        }
    }

    private var providerPicker: some View {
        HStack(spacing: 12) {
            Picker("Provider", selection: $selectedProviderID) {
                ForEach(iosSyncProviderIDs, id: \.self) { id in
                    Text(providerName(for: id)).tag(id)
                }
            }
            .pickerStyle(.segmented)
            .fixedSize(horizontal: true, vertical: false)

            trafficLightDot(size: 10)
                .accessibilityLabel(Text(trafficLightAccessibilityLabel))

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
        .background(.bar)
    }

    private var trafficLight: ProviderLoginTrafficLight {
        _ = sessionChromeEpoch
        return ProviderLoginTrafficLight.resolve(
            isEnabled: true,
            isLoggedIn: sessionHub?.isLoggedIn(for: selectedProviderID)
        )
    }

    private func trafficLightDot(size: CGFloat) -> some View {
        Circle()
            .fill(trafficLight.color)
            .frame(width: size, height: size)
            .help(trafficLight.displayLabel)
    }

    private var trafficLightAccessibilityLabel: String {
        trafficLight.displayLabel
    }

    private func providerName(for id: ProviderID) -> String {
        providerRegistry?.providers.first(where: { $0.id == id })?.displayName ?? id.rawValue
    }

    private var sessionStatus: ProviderSessionStatus {
        _ = sessionChromeEpoch
        return sessionHub?.status(for: selectedProviderID) ?? .needsLogin
    }

    private var lastURLString: String? {
        _ = sessionChromeEpoch
        return sessionHub?.lastURLString(for: selectedProviderID)
    }

    private var canStartSync: Bool {
        guard let syncStore else { return false }
        let targetWebView = webView ?? sessionHub?.webView(for: selectedProviderID)
        guard targetWebView != nil else { return false }
        guard syncStore.isSyncing != true else { return false }
        return sessionStatus == .sessionReady
    }

    private func loginURLForSelectedProvider() -> URL? {
        let provider = providerRegistry?.provider(id: selectedProviderID)
        let loginConfig = provider as? any TravelProviderLoginConfiguration
        return loginConfig?.loginURL
    }

    private func credentialServerHost() -> String? {
        loginURLForSelectedProvider()?.host
    }

    private var sessionBanner: some View {
        HStack(alignment: .center, spacing: 12) {
            trafficLightDot(size: 14)
                .accessibilityLabel(Text(trafficLightAccessibilityLabel))

            VStack(alignment: .leading, spacing: 2) {
                Text(trafficLight.displayLabel)
                    .font(.headline)
                Text(sessionStatus == .sessionReady
                     ? "WebView ist bereit — Buchungen können synchronisiert werden."
                     : "Melde dich im WebView beim Provider an (inkl. 2FA falls nötig).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            }

            Spacer(minLength: 8)

            if let lastURLString {
                Text(lastURLString)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 160, alignment: .trailing)
                    .textSelection(.enabled)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var actionBar: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let statusMessage = syncStore?.statusMessage {
                Text(statusMessage).foregroundStyle(.secondary)
            }
            if let errorMessage = syncStore?.errorMessage {
                syncErrorBanner(errorMessage)
            }

            HStack(spacing: 12) {
                Button {
                    showCredentialSheet = true
                } label: {
                    Label("Konto", systemImage: "key")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(credentialServerHost() == nil)

                Spacer()

                Button {
                    guard let syncStore else { return }
                    let targetWebView = webView ?? sessionHub?.webView(for: selectedProviderID)
                    guard let targetWebView else { return }
                    Task {
                        await syncStore.sync(
                            providerID: selectedProviderID,
                            webView: targetWebView,
                            settings: .fromUserDefaults()
                        )
                    }
                } label: {
                    if syncStore?.isSyncing == true, syncStore?.syncingProviderID == selectedProviderID {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.horizontal, 8)
                    } else {
                        Text("Jetzt synchronisieren")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!canStartSync)
            }
        }
        .padding(16)
        .background(.bar)
    }

    @ViewBuilder
    private func syncErrorBanner(_ errorMessage: String) -> some View {
        let isPermissionDenied = errorMessage.localizedCaseInsensitiveContains("verweigert")
            || errorMessage.localizedCaseInsensitiveContains("denied")
            || errorMessage.localizedCaseInsensitiveContains("Kalenderzugriff")
            || errorMessage.localizedCaseInsensitiveContains("Erinnerungen-Zugriff")

        VStack(alignment: .leading, spacing: 6) {
            Label(
                isPermissionDenied ? "Zugriff verweigert" : "Sync-Fehler",
                systemImage: isPermissionDenied ? "lock.slash" : "exclamationmark.triangle.fill"
            )
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.red)

            Text(errorMessage)
                .foregroundStyle(.red)
                .textSelection(.enabled)
                .font(.footnote)

            if isPermissionDenied {
                Text("Aktiviere unter Einstellungen → Datenschutz den Zugriff auf Kalender bzw. Erinnerungen für „Reisen“.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color.red.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }

    @MainActor
    private func handleWebDidFinish(_ finishedWebView: WKWebView) {
        guard let hub = sessionHub else { return }
        ProviderSessionNavigation.handleDidFinish(
            webView: finishedWebView,
            providerID: selectedProviderID,
            hub: hub,
            enabledProviderIDs: Set(iosSyncProviderIDs),
            notifyAlways: true
        ) {
            sessionChromeEpoch &+= 1
        }
    }
}
