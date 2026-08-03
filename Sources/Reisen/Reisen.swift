import SwiftUI
import SwiftData
import AppKit
import Observation
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenCheck24
import ReisenOpodo
import ReisenBookingCom
import ReisenAirbnb
import ReisenAppCore
import ReisenSharedUI

@main
struct ReisenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var bootstrap = AppBootstrap()

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
                Button("Ausschneiden") {
                    NSApp.sendAction(#selector(NSText.cut(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("x", modifiers: [.command])

                Button("Kopieren") {
                    NSApp.sendAction(#selector(NSText.copy(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("c", modifiers: [.command])

                Button("Einfügen") {
                    NSApp.sendAction(#selector(NSText.paste(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("v", modifiers: [.command])

                Button("Alles auswählen") {
                    NSApp.sendAction(#selector(NSText.selectAll(_:)), to: nil, from: nil)
                }
                .keyboardShortcut("a", modifiers: [.command])
            }

            CommandGroup(replacing: .newItem) {
                Button("Neue Reise…") {
                    NotificationCenter.default.post(name: .reisenNewTrip, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command])

                Button("Buchung hinzufügen…") {
                    NotificationCenter.default.post(name: .reisenAddBooking, object: nil)
                }
                .keyboardShortcut("n", modifiers: [.command, .shift])

                Button("Buchungen zuordnen…") {
                    NotificationCenter.default.post(name: .reisenAssignBookings, object: nil)
                }
            }
            CommandGroup(after: .appInfo) {
                Button("Provider Sync…") {
                    NotificationCenter.default.post(name: .reisenShowProviderSync, object: nil)
                }
                .keyboardShortcut("1", modifiers: [.command])

                Button("Alle Provider synchronisieren") {
                    NotificationCenter.default.post(name: .reisenSyncAllProviders, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command, .shift])

                Button("Aktuellen Provider synchronisieren") {
                    NotificationCenter.default.post(name: .reisenSyncCurrentProvider, object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
            }
            CommandGroup(after: .pasteboard) {
                Button("Reise bearbeiten…") {
                    NotificationCenter.default.post(name: .reisenEditSelectedTrip, object: nil)
                }
            }
        }

        Settings {
            if case .ready(let container, _, _, _) = bootstrap.state {
                ReisenSharedUI.SettingsView(
                    showsDataManagement: true,
                    onResetLocalStores: {
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: false)
                    },
                    onWipeCloudAndReset: {
                        bootstrap.resetStoreAndRetry(wipeCloudDataBeforeReset: true)
                    }
                )
                .modelContainer(container)
            } else {
                Text("Einstellungen sind erst nach erfolgreichem Store-Start verfügbar.")
                    .padding()
            }
        }
    }
}

