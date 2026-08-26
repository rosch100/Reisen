import SwiftUI
import SwiftData
import WebKit

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

struct RootTabView: View {
    let onResetLocalStores: () -> Void
    let onWipeCloudAndReset: () -> Void

    @State private var sessionChromeEpoch = 0
    @State private var providerEnableEpoch = 0
    @State private var selectedTab: AppTab = .reisen
    @State private var installedProviderIDs: Set<ProviderID> = []
    @Environment(\.scenePhase) private var scenePhase

    private enum AppTab: Hashable {
        case reisen, offen, sync, mehr
    }

    private var nativeAppPresenceReader: ProviderNativeAppPresenceReader {
        ProviderNativeAppPresenceReader(isInstalled: { installedProviderIDs.contains($0) })
    }

    @ViewBuilder
    var body: some View {
        ZStack {
            tabs
                .tabViewStyle(.sidebarAdaptable)
                .environment(\.providerNativeAppPresence, nativeAppPresenceReader)
                .environment(\.providerEnableEpoch, providerEnableEpoch)

            SyncBackgroundSessionProbe(
                onSessionChanged: {
                    sessionChromeEpoch &+= 1
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .onAppear {
            refreshProviderAppPresence()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshProviderAppPresence()
            }
        }
        .onProviderEnabledChange(bump: $providerEnableEpoch)
    }

    private func refreshProviderAppPresence() {
        installedProviderIDs = Set(ProviderNativeAppPresence.installedProviderIDs())
        _ = ProviderNativeAppPresence.applyAutoEnableIfNeeded()
    }

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            ReisenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label("Reisen", systemImage: "airplane") }
            .tag(AppTab.reisen)

            OffenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label("Offen", systemImage: "list.bullet.rectangle") }
            .tag(AppTab.offen)

            SyncTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                isSelected: selectedTab == .sync,
                onOpenSettings: { selectedTab = .mehr }
            )
                .tabItem { Label("Sync", systemImage: "arrow.triangle.2.circlepath") }
                .tag(AppTab.sync)

            MoreTab(
                onResetLocalStores: onResetLocalStores,
                onWipeCloudAndReset: onWipeCloudAndReset
            )
                .tabItem { Label("Mehr", systemImage: "ellipsis.circle") }
                .tag(AppTab.mehr)
        }
    }
}
