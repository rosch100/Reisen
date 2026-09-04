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

        let snap = await ProviderPreferencesImportGate.awaitAndApply(
            context: container.mainContext,
            defaults: suite,
            timeout: .milliseconds(50)
        )
        #expect(snap == nil)
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
}
