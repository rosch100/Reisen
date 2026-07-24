import Observation
import SwiftData
import ReisenData
import ReisenDomain
import ReisenProviders
import ReisenCheck24
import ReisenOpodo
import ReisenBookingCom
import ReisenAirbnb

/// Plattformneutraler App- und Store-Bootstrap.
/// UI-spezifische Views (z. B. Copyable Text via AppKit) bleiben weiterhin in den UI-Modulen.
@MainActor
@Observable
public final class AppBootstrap {
    public enum State {
        case ready(ModelContainer, ProviderRegistry, SyncStore, ProviderSessionHub)
        case failed(String)
    }

    public private(set) var state: State

    public init() {
        do {
            self.state = try Self.makeReadyState()
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    public func resetStoreAndRetry() {
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

