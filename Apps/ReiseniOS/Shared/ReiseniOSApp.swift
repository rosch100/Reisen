import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
#if REISEN_PROVIDER_SYNC
import ReisenProviders
import ReisenProviderSync
#endif

@main
struct ReiseniOSApp: App {
    @State private var bootstrap: AppBootstrap
    @Environment(\.scenePhase) private var scenePhase

    init() {
        #if REISEN_PROVIDER_SYNC
        _bootstrap = State(initialValue: AppBootstrap(registry: ProviderSyncBootstrap.makeProviderRegistry()))
        #else
        _bootstrap = State(initialValue: AppBootstrap())
        #endif
    }

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap.state {
                case .ready(let container, let registry, let syncStore, let sessionHub):
                    RootTabView(
                        onResetLocalStores: {
                            bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: false)
                        },
                        onWipeCloudAndReset: {
                            bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: true)
                        }
                    )
                        .environment(\.providerRegistry, registry)
                        .environment(\.syncStore, syncStore)
                        .environment(\.providerSessionHub, sessionHub)
                        .modelContainer(container)
                        .task(id: ObjectIdentifier(syncStore)) {
                            await CloudKitTwoDeviceVerification.runIfRequested(
                                modelContext: container.mainContext
                            )
                            await syncStore.rebuildLocalSideEffects(announceProgress: false)
                        }
                        .onChange(of: scenePhase) { _, phase in
                            guard phase == .active else { return }
                            Task {
                                await syncStore.rebuildLocalSideEffects(announceProgress: false)
                            }
                        }
                case .failed(let message):
                    StoreFailureView(message: message) { wipeCloud in
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: wipeCloud)
                    }
                }
            }
        }
    }
}
