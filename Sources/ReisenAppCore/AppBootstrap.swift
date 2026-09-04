import Foundation
import Observation
import SwiftData
import ReisenData
import ReisenDiagnostics
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
    private let uiTesting: UITestingMode

    public init(
        registry: ProviderRegistry = .empty,
        uiTesting: UITestingMode = .fromProcess,
        crashCatcherInstall: (() -> Void)? = nil,
        crashCatcherFlush: (() async -> Void)? = nil
    ) {
        self.uiTesting = uiTesting
        let install = crashCatcherInstall ?? { GitHubIssueCrashCatcher.install() }
        let flush = crashCatcherFlush ?? { await GitHubIssueCrashCatcher.flushPending() }
        if !uiTesting.skipsSideEffects {
            install()
        }
        do {
            self.state = try Self.makeReadyState(registry: registry, uiTesting: uiTesting)
            startCloudSideEffectObserverIfReady()
            if !uiTesting.skipsSideEffects {
                Task { await flush() }
            }
        } catch {
            self.state = .failed(error.localizedDescription)
            if !uiTesting.skipsSideEffects {
                Task { await flush() }
            }
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
            if uiTesting.skipsSideEffects {
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
        if uiTesting.skipsSideEffects {
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
        let provisional = try Self.makeReadyState(registry: currentRegistry, uiTesting: uiTesting)
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
        state = try Self.makeReadyState(registry: currentRegistry, uiTesting: uiTesting)
        startCloudSideEffectObserverIfReady()
    }

    private func startCloudSideEffectObserverIfReady() {
        guard !uiTesting.skipsSideEffects else { return }
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
        applyProviderEnabledDefaultsMigration(uiTesting: uiTesting)
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

    /// Frischinstall: Provider opt-in. Upgrade: frühere implizite Aktivierung materialisieren.
    /// Populated-UITesting: Portale explizit an, damit Sync-Chrome/Cmd-1 erreichbar bleibt.
    private static func applyProviderEnabledDefaultsMigration(uiTesting: UITestingMode) {
        if uiTesting.skipsSideEffects {
            AppSettingsDefaults.installOverride(UITestingLaunch.isolatedDefaults)
        } else {
            AppSettingsDefaults.installOverride(nil)
        }
        let defaults = AppSettingsDefaults.current
        let wasExistingInstall = ProviderEnabledDefaultsMigration.looksLikeExistingInstall(defaults: defaults)
        let didMigrate = ProviderEnabledDefaultsMigration.migrateIfNeeded(defaults: defaults)
        let didRepairFalsePositive = ProviderEnabledDefaultsMigration.repairFalsePositiveAllOnIfNeeded(
            defaults: defaults
        )
        ProviderFirstLaunchSetup.bootstrapCompletedIfExistingProviders(defaults: defaults)
        UITestingLaunch.seedProviderEnablementIfNeeded(mode: uiTesting, defaults: defaults)
        UITestingLaunch.seedProviderSetupIfNeeded(mode: uiTesting, defaults: defaults)
        guard !uiTesting.skipsSideEffects else { return }
        let runID = UUID()
        if didMigrate {
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: DiagnosticContext(
                            runID: runID,
                            providerID: .manual,
                            operation: "provider_enabled_defaults_migration"
                        ),
                        component: "AppBootstrap",
                        phase: "settings",
                        event: "provider_enabled_opt_in_migrated",
                        result: .succeeded,
                        reason: wasExistingInstall
                            ? "existing_install_materialized"
                            : "fresh_install_opt_in"
                    )
                )
            }
        }
        if didRepairFalsePositive {
            Task {
                await DiagnosticLogger.shared.record(
                    DiagnosticEvent(
                        context: DiagnosticContext(
                            runID: runID,
                            providerID: .manual,
                            operation: "provider_enabled_false_positive_repair"
                        ),
                        component: "AppBootstrap",
                        phase: "settings",
                        event: "provider_enabled_false_positive_repaired",
                        result: .succeeded,
                        reason: "all_on_without_configured_account"
                    )
                )
            }
        }
    }
}
