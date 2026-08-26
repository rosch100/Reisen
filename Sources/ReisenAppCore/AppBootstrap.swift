import Observation
import SwiftData
import ReisenData
import ReisenDomain
import ReisenProviders
import ReisenCheck24
import ReisenOpodo
import ReisenBookingCom
import ReisenAirbnb
import ReisenGetYourGuide
import ReisenTraveloka

/// Plattformneutraler App- und Store-Bootstrap.
/// UI-spezifische Views (z. B. CopyableText via AppKit) bleiben weiterhin in den UI-Modulen.
@MainActor
@Observable
public final class AppBootstrap {
    public enum State {
        case ready(ModelContainer, ProviderRegistry, SyncStore, ProviderSessionHub)
        case failed(String)
    }

    public private(set) var state: State
    public private(set) var isResetting = false

    public init() {
        do {
            self.state = try Self.makeReadyState()
            startCloudSideEffectObserverIfReady()
        } catch {
            self.state = .failed(error.localizedDescription)
        }
    }

    /// Wipes local store files and reopens the container.
    /// - Note: With iCloud/CloudKit enabled, syncable data may reappear from the account
    ///   unless it was previously deleted via `wipeCloudDataBeforeReset`.
    public func resetStoreAndRetry(wipeCloudDataBeforeReset: Bool = false) {
        guard !isResetting else { return }
        isResetting = true
        Task { @MainActor in
            defer { isResetting = false }
            await performReset(wipeCloudDataBeforeReset: wipeCloudDataBeforeReset)
        }
    }

    private func performReset(wipeCloudDataBeforeReset: Bool) async {
        do {
            stopCloudSideEffectObserverIfReady()

            if wipeCloudDataBeforeReset {
                try await wipeCloudThenResetLocal()
            } else {
                try PersistenceBootstrap.resetStoreFiles()
                try activateReadyState()
            }
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    /// Cloud wipe works from `.ready` (delete+export) or `.failed` (reopen → import → delete → export).
    private func wipeCloudThenResetLocal() async throws {
        if case .ready(let container, _, _, _) = state {
            try await wipeCloud(from: container.mainContext)
            try PersistenceBootstrap.resetStoreFiles()
            try activateReadyState()
            return
        }

        // Store could not open: recreate local files, pull cloud data, then tombstone it.
        try PersistenceBootstrap.resetStoreFiles()
        let provisional = try Self.makeReadyState()
        guard case .ready(let container, _, _, _) = provisional else {
            throw PersistenceStoreError.storeIncompatible(
                "Cloud-Wipe nach Store-Fehler: Container konnte nicht geöffnet werden."
            )
        }
        await PersistenceBootstrap.awaitCloudKitImportIfNeeded()
        try await wipeCloud(from: container.mainContext)
        state = provisional
        startCloudSideEffectObserverIfReady()
    }

    private func wipeCloud(from context: ModelContext) async throws {
        try PersistenceBootstrap.wipeSyncedEntities(in: context, includeLocal: true)
        await PersistenceBootstrap.awaitCloudKitExportIfNeeded()
    }

    private func activateReadyState() throws {
        state = try Self.makeReadyState()
        startCloudSideEffectObserverIfReady()
    }

    private func startCloudSideEffectObserverIfReady() {
        if case .ready(_, _, let syncStore, _) = state {
            syncStore.startObservingCloudSideEffects()
        }
    }

    private func stopCloudSideEffectObserverIfReady() {
        if case .ready(_, _, let syncStore, _) = state {
            syncStore.stopObservingCloudSideEffects()
        }
    }

    private static func makeReadyState() throws -> State {
        let container = try PersistenceBootstrap.makeContainer()
        let registry = makeProviderRegistry()
        let syncStore = SyncStore(modelContext: container.mainContext, registry: registry)
        let sessionHub = ProviderSessionHub()
        return .ready(container, registry, syncStore, sessionHub)
    }

    /// Produktions-Registry; Reihenfolge und Inhalt folgen `ProviderID.syncProviderIDs`.
    public static func makeProviderRegistry() -> ProviderRegistry {
        let providersByID: [ProviderID: any TravelProvider] = [
            .check24: Check24TravelProvider(),
            .opodo: OpodoTravelProvider(),
            .booking: BookingComTravelProvider(),
            .airbnb: AirbnbTravelProvider(),
            .getYourGuide: GetYourGuideTravelProvider(),
            .traveloka: TravelokaTravelProvider(),
        ]
        let providers = ProviderID.syncProviderIDs.compactMap { providersByID[$0] }
        precondition(
            providers.count == ProviderID.syncProviderIDs.count,
            "ProviderRegistry: fehlende Implementierung für \(Set(ProviderID.syncProviderIDs).subtracting(providers.map(\.id)))"
        )

        return ProviderRegistry(
            providers: providers,
            deepLinkBuilders: [
                Check24DeepLinkBuilder(),
                TravelokaDeepLinkBuilder(),
            ]
        )
    }
}
