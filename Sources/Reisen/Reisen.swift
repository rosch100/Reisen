import SwiftUI
import SwiftData
import AppKit
import Observation
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenAppCore
import ReisenProviderSync
import ReisenSharedUI

@main
struct ReisenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap(registry: ProviderSyncBootstrap.makeProviderRegistry())

    var body: some Scene {
        WindowGroup {
            Group {
                switch bootstrap.state {
                case .ready(let container, let registry, let syncStore, let sessionHub):
                    ContentView()
                        .environment(\.providerRegistry, registry)
                        .environment(\.syncStore, syncStore)
                        .environment(\.providerSessionHub, sessionHub)
                        .modelContainer(container)
                        .task(id: ObjectIdentifier(syncStore)) {
                            // Verification first: rebuild/EventKit must not block seed/expect.
                            await CloudKitTwoDeviceVerification.runIfRequested(
                                modelContext: container.mainContext
                            )
                            // Rebuild local EventKit/Reminders after CloudKit catch-up on launch.
                            await syncStore.rebuildLocalSideEffects(announceProgress: false)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                            Task {
                                await syncStore.rebuildLocalSideEffects(announceProgress: false)
                            }
                        }
                case .failed(let message):
                    StoreFailureView(
                        message: message,
                        contentPadding: 32,
                        minFrame: CGSize(width: 520, height: 240)
                    ) { wipeCloud in
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: wipeCloud)
                    }
                }
            }
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.automatic)
        .commands {
            ReisenCommands()
        }

        Window(L10n.string(.editorCreateTitle), id: PasteImportReviewPresenter.windowID) {
            if case .ready(let container, _, _, _) = bootstrap.state {
                PasteImportReviewWindowView(presenter: PasteImportReviewPresenter.shared)
                    .modelContainer(container)
            } else {
                Text(L10n.string(.appSettingsUnavailable))
                    .padding()
            }
        }
        .defaultSize(width: 560, height: 720)
        .windowResizability(.contentSize)

        Settings {
            if case .ready(let container, let registry, let syncStore, _) = bootstrap.state {
                ReisenSharedUI.SettingsView(
                    showsProviderSyncSettings: true,
                    showsDataManagement: true,
                    onResetLocalStores: {
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: false)
                    },
                    onWipeCloudAndReset: {
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: true)
                    }
                )
                .environment(\.providerRegistry, registry)
                .environment(\.syncStore, syncStore)
                .modelContainer(container)
            } else {
                Text(L10n.string(.appSettingsUnavailable))
                    .padding()
            }
        }
    }
}

