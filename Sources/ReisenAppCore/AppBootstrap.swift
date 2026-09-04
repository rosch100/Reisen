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

    /// Live CloudKit on/off: persists preference, optionally wipes iCloud, reopens the hybrid store.
    public func applyICloudSyncPreference(enabled: Bool, wipeCloud: Bool) async {
        guard !isResetting else {
            await recordICloudSyncPreference(
                runID: UUID(),
                event: "apply_skipped",
                result: .skipped,
                reason: "busy_resetting"
            )
            return
        }
        isResetting = true
        defer { isResetting = false }
        await performApplyICloudSyncPreference(enabled: enabled, wipeCloud: wipeCloud)
    }

    private func performApplyICloudSyncPreference(enabled: Bool, wipeCloud: Bool) async {
        let defaults = AppSettingsDefaults.current
        let previous = AppSettingsKeys.isICloudSyncEnabled(defaults: defaults)
        let reason: String
        if enabled {
            reason = "user_enable"
        } else if wipeCloud {
            reason = "user_disable_wipe"
        } else {
            reason = "user_disable_keep_local"
        }
        let runID = UUID()
        await recordICloudSyncPreference(
            runID: runID,
            event: "apply_started",
            result: .started,
            reason: reason
        )

        /// After cloud wipe + store-file delete, do not restore the previous preference on reopen failure.
        var revertPreferenceOnFailure = true

        do {
            stopCloudSideEffectObserverIfReady()

            if uiTesting.skipsSideEffects {
                AppSettingsKeys.setICloudSyncEnabled(enabled, defaults: defaults)
                try activateReadyState()
            } else if !enabled && wipeCloud {
                // Keep preference ON until wipe finishes so a `.failed` provisional store still
                // opens with CloudKit, imports remote records, and can tombstone them.
                _ = try await wipeCloudDataAndDeleteStoreFiles()
                stopCloudSideEffectObserverIfReady()
                AppSettingsKeys.setICloudSyncEnabled(false, defaults: defaults)
                revertPreferenceOnFailure = false
                // Always reopen so Effective CloudKit matches the new opt-out (failed-path
                // provisional may still have been opened with CloudKit while preference was on).
                try activateReadyState()
            } else {
                AppSettingsKeys.setICloudSyncEnabled(enabled, defaults: defaults)
                // Keep local store files; makeContainer uses Effective CloudKit (Env × preference).
                try activateReadyState()
            }

            await recordICloudSyncPreference(
                runID: runID,
                event: "apply_succeeded",
                result: .succeeded,
                reason: reason
            )
        } catch {
            if revertPreferenceOnFailure {
                AppSettingsKeys.setICloudSyncEnabled(previous, defaults: defaults)
            }
            state = .failed(error.localizedDescription)
            await recordICloudSyncPreference(
                runID: runID,
                event: "apply_failed",
                result: .failed,
                reason: reason
            )
        }
    }

    private func recordICloudSyncPreference(
        runID: UUID,
        event: String,
        result: DiagnosticResult,
        reason: String
    ) async {
        guard !uiTesting.skipsSideEffects else { return }
        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: DiagnosticContext(
                    runID: runID,
                    providerID: .manual,
                    operation: "icloud_sync_preference"
                ),
                component: "ICloudSyncPreference",
                phase: "apply",
                event: event,
                result: result,
                reason: reason,
                visibility: .publicDiagnostic
            )
        )
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

        if try await wipeCloudDataAndDeleteStoreFiles() {
            try activateReadyState()
        }
    }

    /// Tombstones synced entities (when possible) and deletes on-disk store files.
    /// - Returns: `true` if the caller must reopen via `activateReadyState()`; `false` if already ready.
    private func wipeCloudDataAndDeleteStoreFiles() async throws -> Bool {
        if case .ready(let container, _, _, _) = state {
            try await wipeCloud(from: container.mainContext)
            try PersistenceBootstrap.resetStoreFiles()
            return true
        }

        // Store could not open: recreate local files, pull cloud data, then tombstone it.
        try PersistenceBootstrap.resetStoreFiles()
        let provisional = try Self.makeReadyState(registry: currentRegistry, uiTesting: uiTesting)
        guard case .ready(let container, _, _, _) = provisional else {
            throw PersistenceStoreError.storeIncompatible(
                "Cloud-Wipe nach Store-Fehler: Container konnte nicht geöffnet werden."
            )
        }
        await PersistenceBootstrap.awaitCloudKitImportIfNeeded(
            cloudKitEnabled: Self.isEffectiveCloudKitEnabled()
        )
        try await wipeCloud(from: container.mainContext)
        state = provisional
        startCloudSideEffectObserverIfReady()
        return false
    }

    private var currentRegistry: ProviderRegistry {
        if case .ready(_, let registry, _, _) = state {
            return registry
        }
        return .empty
    }

    private func wipeCloud(from context: ModelContext) async throws {
        try PersistenceBootstrap.wipeSyncedEntities(in: context, includeLocal: true)
        await PersistenceBootstrap.awaitCloudKitExportIfNeeded(
            cloudKitEnabled: Self.isEffectiveCloudKitEnabled()
        )
    }

    private func activateReadyState() throws {
        state = try Self.makeReadyState(registry: currentRegistry, uiTesting: uiTesting)
        startCloudSideEffectObserverIfReady()
    }

    /// Env × `AppSettingsKeys` preference — resolved in AppCore, never inside ReisenData.
    private static func isEffectiveCloudKitEnabled() -> Bool {
        PersistenceBootstrap.isCloudKitEnabledByEnvironment(
            iCloudSyncPreferenceEnabled: AppSettingsKeys.isICloudSyncEnabled()
        )
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
            container = try PersistenceBootstrap.makeContainer(
                cloudKitEnabled: isEffectiveCloudKitEnabled()
            )
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
        _ = ProviderEnabledDefaultsMigration.migrateFalsePositiveRepairSemanticsV3IfNeeded(
            defaults: defaults
        )
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
                        reason: "all_on_incomplete_preferred_accounts"
                    )
                )
            }
        }
    }
}
