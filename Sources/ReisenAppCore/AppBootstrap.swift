import Observation
import SwiftData
import ReisenData
import ReisenDomain

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

    public init(registry: ProviderRegistry = .empty) {
        GitHubIssueCrashCatcher.install()
        do {
            self.state = try Self.makeReadyState(registry: registry)
            startCloudSideEffectObserverIfReady()
            Task { await GitHubIssueCrashCatcher.flushPending() }
        } catch {
            self.state = .failed(error.localizedDescription)
            Task { await GitHubIssueCrashCatcher.flushPending() }
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

            // UI-Tests laufen nur In-Memory: keine Disk-SQLite löschen, nur Ready-State neu aufbauen.
            if UITestingMode.fromProcess.skipsSideEffects {
                try activateReadyState()
                return
            }

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
        if UITestingMode.fromProcess.skipsSideEffects {
            try activateReadyState()
            return
        }

        if case .ready(let container, _, _, _) = state {
            try await wipeCloud(from: container.mainContext)
            try PersistenceBootstrap.resetStoreFiles()
            try activateReadyState()
            return
        }

        // Store could not open: recreate local files, pull cloud data, then tombstone it.
        try PersistenceBootstrap.resetStoreFiles()
        let provisional = try Self.makeReadyState(registry: currentRegistry)
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

    private var currentRegistry: ProviderRegistry {
        if case .ready(_, let registry, _, _) = state {
            return registry
        }
        return .empty
    }

    private func wipeCloud(from context: ModelContext) async throws {
        try PersistenceBootstrap.wipeSyncedEntities(in: context, includeLocal: true)
        await PersistenceBootstrap.awaitCloudKitExportIfNeeded()
    }

    private func activateReadyState() throws {
        state = try Self.makeReadyState(registry: currentRegistry)
        startCloudSideEffectObserverIfReady()
    }

    private func startCloudSideEffectObserverIfReady() {
        guard !UITestingMode.fromProcess.skipsSideEffects else { return }
        if case .ready(_, _, let syncStore, _) = state {
            syncStore.startObservingCloudSideEffects()
        }
    }

    private func stopCloudSideEffectObserverIfReady() {
        if case .ready(_, _, let syncStore, _) = state {
            syncStore.stopObservingCloudSideEffects()
        }
    }

    public static func makeReadyState(
        registry: ProviderRegistry = .empty,
        uiTesting: UITestingMode = .fromProcess
    ) throws -> State {
        let container: ModelContainer
        if uiTesting.skipsSideEffects {
            container = try PersistenceBootstrap.makeInMemoryContainer()
            if uiTesting == .populated {
                try UITestingSeed.insertPopulated(into: container.mainContext)
            }
        } else {
            container = try PersistenceBootstrap.makeContainer()
        }
        let syncStore = SyncStore(modelContext: container.mainContext, registry: registry)
        let sessionHub = ProviderSessionHub()
        return .ready(container, registry, syncStore, sessionHub)
    }
}
