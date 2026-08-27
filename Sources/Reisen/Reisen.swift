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
            CommandGroup(replacing: .pasteboard) {
                Button(L10n.string(.commonCut)) {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: [.command])

                Button(L10n.string(.commonCopy)) {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: [.command])

                Button(L10n.string(.commonPaste)) {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: [.command])

                Button(L10n.string(.commonSelectAll)) {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: [.command])
            }

            CommandGroup(replacing: .newItem) {
                Button(L10n.string(.menuNewTrip)) {
                    NotificationCenter.default.post(name: .reisenNewTrip, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button(L10n.string(.menuAddBooking)) {
                    NotificationCenter.default.post(name: .reisenAddBooking, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button(L10n.string(.menuAssignBookings)) {
                    NotificationCenter.default.post(name: .reisenAssignBookings, object: nil)
                }
            }
            CommandGroup(after: .appInfo) {
                Button(L10n.string(.menuProviderSync)) {
                    NotificationCenter.default.post(name: .reisenShowProviderSync, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button(L10n.string(.menuSyncAllProviders)) {
                    NotificationCenter.default.post(name: .reisenSyncAllProviders, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button(L10n.string(.menuSyncCurrentProvider)) {
                    NotificationCenter.default.post(name: .reisenSyncCurrentProvider, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(after: .pasteboard) {
                Button(L10n.string(.menuEditTrip)) {
                    NotificationCenter.default.post(name: .reisenEditSelectedTrip, object: nil)
                }
            }
        }

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

