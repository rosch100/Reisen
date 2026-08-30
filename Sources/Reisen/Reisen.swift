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
    @State private var bootstrap: AppBootstrap?

    var body: some Scene {
        // Ein festes Hauptfenster, kein WindowGroup: Document-Types + Ignore-State
        // unterdrücken sonst die automatische Szene (nur Menüleiste, kein AX-Fenster).
        Window("Reisen", id: Self.mainWindowID) {
            Group {
                if let bootstrap {
                    switch bootstrap.state {
                    case .ready(let container, let registry, let syncStore, let sessionHub):
                        ContentView()
                            .environment(\.providerRegistry, registry)
                            .environment(\.syncStore, syncStore)
                            .environment(\.providerSessionHub, sessionHub)
                            .modelContainer(container)
                            .uiTestingIsolation()
                            .task(id: ObjectIdentifier(syncStore)) {
                                guard !UITestingLaunch.isActive else { return }
                                await CloudKitTwoDeviceVerification.runIfRequested(
                                    modelContext: container.mainContext
                                )
                                await syncStore.rebuildLocalSideEffects(announceProgress: false)
                            }
                            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                                guard !UITestingLaunch.isActive else { return }
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
                } else {
                    ProgressView()
                        .controlSize(.large)
                        .frame(minWidth: 960, minHeight: 640)
                }
            }
            .onAppear {
                guard bootstrap == nil else { return }
                bootstrap = AppBootstrap(registry: ProviderSyncBootstrap.makeProviderRegistry())
            }
        }
        .defaultSize(width: 1180, height: 780)
        .windowResizability(.automatic)
        .defaultLaunchBehavior(.presented)
        .commands {
            ReisenCommands()
        }

        Window(L10n.string(.editorCreateTitle), id: PasteImportReviewPresenter.windowID) {
            if case .ready(let container, _, _, _) = bootstrap?.state {
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
            if case .ready(let container, let registry, let syncStore, _) = bootstrap?.state {
                ReisenSharedUI.SettingsView(
                    showsProviderSyncSettings: true,
                    showsDataManagement: true,
                    onResetLocalStores: {
                        bootstrap?.resetStoreAndRetry(wipeCloudDataBeforeReset: false)
                    },
                    onWipeCloudAndReset: {
                        bootstrap?.resetStoreAndRetry(wipeCloudDataBeforeReset: true)
                    }
                )
                .environment(\.providerRegistry, registry)
                .environment(\.syncStore, syncStore)
                .modelContainer(container)
                .uiTestingIsolation()
            } else {
                Text(L10n.string(.appSettingsUnavailable))
                    .padding()
            }
        }
    }

    private static let mainWindowID = "reisen.main"
}

