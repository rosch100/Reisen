import SwiftUI
import SwiftData
#if REISEN_PROVIDER_SYNC
import WebKit
#endif

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
#if REISEN_PROVIDER_SYNC
import ReisenProviders
#endif

struct RootTabView: View {
    let onResetLocalStores: () -> Void
    let onWipeCloudAndReset: () -> Void

    @State private var sessionChromeEpoch = 0
    @State private var providerEnableEpoch = 0
    @State private var selectedTab: AppTab = .reisen
    #if REISEN_PROVIDER_SYNC
    @State private var installedProviderIDs: Set<ProviderID> = []
    #endif
    @Environment(\.scenePhase) private var scenePhase

    private enum AppTab: Hashable {
        case reisen, offen
        #if REISEN_PROVIDER_SYNC
        case sync
        #endif
        case mehr
    }

    #if REISEN_PROVIDER_SYNC
    private var nativeAppPresenceReader: ProviderNativeAppPresenceReader {
        ProviderNativeAppPresenceReader(isInstalled: { installedProviderIDs.contains($0) })
    }
    #endif

    @ViewBuilder
    var body: some View {
        ZStack {
            tabs
                .tabViewStyle(.sidebarAdaptable)
                #if REISEN_PROVIDER_SYNC
                .environment(\.providerNativeAppPresence, nativeAppPresenceReader)
                .environment(\.providerEnableEpoch, providerEnableEpoch)
                #endif

            #if REISEN_PROVIDER_SYNC
            SyncBackgroundSessionProbe(
                onSessionChanged: {
                    sessionChromeEpoch &+= 1
                }
            )
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            #endif
        }
        #if REISEN_PROVIDER_SYNC
        .onAppear {
            refreshProviderAppPresence()
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshProviderAppPresence()
            }
        }
        .onProviderEnabledChange(bump: $providerEnableEpoch)
        #endif
    }

    #if REISEN_PROVIDER_SYNC
    private func refreshProviderAppPresence() {
        installedProviderIDs = Set(ProviderNativeAppPresence.installedProviderIDs())
        _ = ProviderNativeAppPresence.applyAutoEnableIfNeeded()
    }
    #endif

    private var tabs: some View {
        TabView(selection: $selectedTab) {
            #if REISEN_PROVIDER_SYNC
            ReisenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label(L10n.string(.tabTrips), systemImage: "airplane") }
            .tag(AppTab.reisen)
            #else
            ReisenTab(sessionChromeEpoch: $sessionChromeEpoch)
            .tabItem { Label(L10n.string(.tabTrips), systemImage: "airplane") }
            .tag(AppTab.reisen)
            #endif

            #if REISEN_PROVIDER_SYNC
            OffenTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                onOpenSync: { selectedTab = .sync }
            )
            .tabItem { Label(L10n.string(.tabOpen), systemImage: "list.bullet.rectangle") }
            .tag(AppTab.offen)
            #else
            OffenTab(sessionChromeEpoch: $sessionChromeEpoch)
            .tabItem { Label(L10n.string(.tabOpen), systemImage: "list.bullet.rectangle") }
            .tag(AppTab.offen)
            #endif

            #if REISEN_PROVIDER_SYNC
            SyncTab(
                sessionChromeEpoch: $sessionChromeEpoch,
                isSelected: selectedTab == .sync,
                onOpenSettings: { selectedTab = .mehr }
            )
                .tabItem { Label(L10n.string(.tabSync), systemImage: "arrow.triangle.2.circlepath") }
                .tag(AppTab.sync)
            #endif

            MoreTab(
                onResetLocalStores: onResetLocalStores,
                onWipeCloudAndReset: onWipeCloudAndReset
            )
                .tabItem { Label(L10n.string(.tabMore), systemImage: "ellipsis.circle") }
                .tag(AppTab.mehr)
        }
    }
}
