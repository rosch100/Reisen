import SwiftUI
import SwiftData
import AppKit
import ReisenDomain
import ReisenData
import ReisenProviders
import ReisenCheck24
import ReisenOpodo
import ReisenBookingCom
import ReisenAirbnb

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
                case .failed(let message):
                    StoreFailureView(message: message) {
                        bootstrap.resetStoreAndRetry()
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
                SettingsView()
                    .modelContainer(container)
            } else {
                Text("Einstellungen sind erst nach erfolgreichem Store-Start verfügbar.")
                    .padding()
            }
        }
    }
}

@MainActor
@Observable
final class AppBootstrap {
    enum State {
        case ready(ModelContainer, ProviderRegistry, SyncStore, ProviderSessionHub)
        case failed(String)
    }

    private(set) var state: State

    init() {
        do {
            self.state = try Self.makeReadyState()
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    func resetStoreAndRetry() {
        do {
            try PersistenceBootstrap.resetStoreFiles()
            state = try Self.makeReadyState()
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    private static func makeReadyState() throws -> State {
        let container = try PersistenceBootstrap.makeContainer()
        let registry = makeRegistry()
        let syncStore = SyncStore(modelContext: container.mainContext, registry: registry)
        let sessionHub = ProviderSessionHub()
        return .ready(container, registry, syncStore, sessionHub)
    }

    private static func makeRegistry() -> ProviderRegistry {
        ProviderRegistry(
            providers: [
                Check24TravelProvider(),
                OpodoTravelProvider(),
                BookingComTravelProvider(),
                AirbnbTravelProvider()
            ],
            deepLinkBuilders: [Check24DeepLinkBuilder()]
        )
    }
}

private struct StoreFailureView: View {
    let message: String
    let onReset: () -> Void
    @State private var showResetConfirmation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Datenbank konnte nicht geladen werden")
                .font(.title2)
            CopyableTextView(
                text: message,
                font: .preferredFont(forTextStyle: .body),
                textColor: .secondaryLabelColor
            )
            Button("Lokale Datenbank zurücksetzen und erneut versuchen…") {
                showResetConfirmation = true
            }
                .buttonStyle(.borderedProminent)
                .confirmationDialog(
                    "Lokale Datenbank zurücksetzen?",
                    isPresented: $showResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Zurücksetzen", role: .destructive, action: onReset)
                    Button("Abbrechen", role: .cancel) {}
                } message: {
                    Text("Alle lokal gespeicherten Reisen und Buchungen werden unwiderruflich gelöscht.")
                }
        }
        .padding(32)
        .frame(minWidth: 520, minHeight: 240)
    }
}
