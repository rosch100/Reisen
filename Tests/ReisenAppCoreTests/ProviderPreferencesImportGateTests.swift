import Testing
import Foundation
import SwiftData
import ReisenAppCore
import ReisenData
import ReisenDomain

@MainActor
@Suite("ProviderPreferencesImportGate")
struct ProviderPreferencesImportGateTests {
    @Test("test host skips CloudKit wait")
    func skipWaitOnTestHost() async throws {
        #expect(ProviderPreferencesImportGate.shouldSkipCloudKitWait)

        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.gate.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let outcome = await ProviderPreferencesImportGate.awaitAndApply(
            context: container.mainContext,
            defaults: suite,
            timeout: .milliseconds(50)
        )
        #expect(outcome == .noRecord)
        #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: suite))
    }

    @Test("test host does not observe remote prefs changes")
    func skipRemoteObserveOnTestHost() {
        #expect(!ProviderPreferencesImportGate.shouldObserveRemoteChanges)
    }

    @Test("applyRemoteChange is a no-op when remote observe is disabled")
    func applyRemoteNoOpWithoutObserve() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.gate.remote.\(UUID().uuidString)"
        let sourceName = "test.prefs.gate.remote.source.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        let source = UserDefaults(suiteName: sourceName)!
        defer {
            suite.removePersistentDomain(forName: suiteName)
            source.removePersistentDomain(forName: sourceName)
        }

        ProviderPreferencesSnapshot(
            setupCompleted: true,
            enabledProviderIDs: [.check24]
        ).apply(to: source)
        try ProviderPreferencesMirror.export(from: source, into: container.mainContext)

        #expect(ProviderPreferencesImportGate.applyRemoteChange(
            context: container.mainContext,
            defaults: suite
        ) == nil)
        #expect(!suite.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    }

    @Test("notifyEnabledAfterImport suppresses export")
    func notifyAfterImportSuppressesExport() throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.gate.suppress.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        ProviderPreferencesSnapshot(
            setupCompleted: true,
            enabledProviderIDs: [.check24]
        ).apply(to: suite)

        ProviderPreferencesImportGate.exportFromDefaults(
            context: container.mainContext,
            defaults: suite
        )
        #expect(try ProviderPreferencesMirror.fetchCanonical(in: container.mainContext) != nil)

        if let existing = try ProviderPreferencesMirror.fetchCanonical(in: container.mainContext) {
            container.mainContext.delete(existing)
            try container.mainContext.save()
        }
        #expect(try ProviderPreferencesMirror.fetchCanonical(in: container.mainContext) == nil)

        ProviderPreferencesImportGate.notifyEnabledAfterImport()
        ProviderPreferencesImportGate.exportFromDefaults(
            context: container.mainContext,
            defaults: suite
        )
        #expect(try ProviderPreferencesMirror.fetchCanonical(in: container.mainContext) == nil)
    }

    @Test("importApplying returns equal snapshot without rewriting defaults")
    func importApplyingSkipsRewriteWhenUnchanged() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let suiteName = "test.prefs.gate.unchanged.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        suite.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
        suite.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
        #expect(try ProviderPreferencesMirror.export(from: suite, into: context) == true)

        let before = ProviderPreferencesSnapshot.read(from: suite)
        let imported = try ProviderPreferencesMirror.importApplying(from: context, into: suite)
        #expect(imported == before)
        #expect(ProviderPreferencesSnapshot.read(from: suite) == before)
    }

    @Test("false-positive repair clears poisoned mirror instead of re-infecting defaults")
    func clearsPoisonedMirrorAfterFalsePositiveRepair() async throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.gate.poison.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let syncIDs = ProviderID.syncProviderIDs
        ProviderFirstLaunchSetup.applySelection(
            enabledIDs: Set(syncIDs),
            syncProviderIDs: syncIDs,
            defaults: suite
        )
        ProviderFirstLaunchSetup.markCompleted(defaults: suite)
        try ProviderPreferencesMirror.export(from: suite, into: container.mainContext)

        // Lokal bereits repariert; Mirror noch mit All-On + setupCompleted.
        ProviderEnabledDefaultsMigration.resetToOptInClearingSetup(
            syncProviderIDs: syncIDs,
            defaults: suite
        )
        suite.set(true, forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)

        let outcome = await ProviderPreferencesImportGate.awaitAndApply(
            context: container.mainContext,
            defaults: suite,
            timeout: .milliseconds(50)
        )

        #expect(outcome == .noRecord)
        #expect(!suite.bool(forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey))
        #expect(ProviderFirstLaunchSetup.shouldPresent(defaults: suite))
        for providerID in syncIDs {
            #expect(!AppSettingsKeys.isProviderEnabled(providerID, defaults: suite))
            #expect(suite.object(forKey: AppSettingsKeys.providerEnabledKey(for: providerID)) == nil)
        }
        #expect(try ProviderPreferencesMirror.fetchCanonical(in: container.mainContext) == nil)
    }

    @Test("awaitAndApply returns applied when singleton prefs exist")
    func awaitAndApplyReturnsAppliedSnapshot() async throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.gate.applied.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        ProviderPreferencesSnapshot(
            setupCompleted: true,
            enabledProviderIDs: [.opodo]
        ).apply(to: suite)
        try ProviderPreferencesMirror.export(from: suite, into: container.mainContext)

        let targetName = "test.prefs.gate.applied.target.\(UUID().uuidString)"
        let target = UserDefaults(suiteName: targetName)!
        defer { target.removePersistentDomain(forName: targetName) }

        let outcome = await ProviderPreferencesImportGate.awaitAndApply(
            context: container.mainContext,
            defaults: target,
            timeout: .milliseconds(50)
        )
        guard case .applied(let snap) = outcome else {
            Issue.record("expected applied outcome, got \(outcome)")
            return
        }
        #expect(snap.setupCompleted)
        #expect(target.bool(forKey: AppSettingsKeys.providerSetupCompleted))
        #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: target))
    }

    @Test("awaitApplyAndSeedLocalIfEmpty returns setupCompletedFromCloud when prefs applied")
    func awaitApplyAndSeedReturnsCompletedFromCloud() async throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.startup.cloud.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        ProviderPreferencesSnapshot(
            setupCompleted: true,
            enabledProviderIDs: [.opodo]
        ).apply(to: suite)
        try ProviderPreferencesMirror.export(from: suite, into: container.mainContext)

        let targetName = "test.prefs.startup.cloud.target.\(UUID().uuidString)"
        let target = UserDefaults(suiteName: targetName)!
        defer { target.removePersistentDomain(forName: targetName) }

        let result = await ProviderPreferencesImportGate.awaitApplyAndSeedLocalIfEmpty(
            context: container.mainContext,
            defaults: target,
            timeout: .milliseconds(50)
        )
        #expect(result == .setupCompletedFromCloud)
        #expect(target.bool(forKey: AppSettingsKeys.providerSetupCompleted))
    }

    @Test("awaitApplyAndSeedLocalIfEmpty continues local setup when no record")
    func awaitApplyAndSeedContinuesWhenEmpty() async throws {
        let container = try PersistenceBootstrap.makeInMemoryContainer()
        let suiteName = "test.prefs.startup.empty.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let result = await ProviderPreferencesImportGate.awaitApplyAndSeedLocalIfEmpty(
            context: container.mainContext,
            defaults: suite,
            timeout: .milliseconds(50)
        )
        #expect(result == .continueLocalSetup)
    }
}
