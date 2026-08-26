import SwiftUI
import SwiftData

import ReisenAppCore
import ReisenSharedUI
import ReisenDomain
import ReisenData
import ReisenProviders

@main
struct ReiseniOSApp: App {
    @State private var bootstrap = AppBootstrap()
    @Environment(\.scenePhase) private var scenePhase

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
                            // Verification first: rebuild/EventKit must not block seed/expect.
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
