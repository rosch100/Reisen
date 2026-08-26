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
    @State private var selectedTab: AppTab = .reisen

    private enum AppTab: Hashable {
        case reisen, offen, sync, mehr
    }

    @ViewBuilder
    var body: some View {
        ZStack {
            tabs
                .tabViewStyle(.sidebarAdaptable)

            SyncBackgroundSessionProbe(onSessionChanged: {
                sessionChromeEpoch &+= 1
            })
            .frame(width: 1, height: 1)
            .opacity(0.01)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
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
                isSelected: selectedTab == .sync
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
