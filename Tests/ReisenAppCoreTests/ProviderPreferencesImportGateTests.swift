import Testing
import Foundation
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
}
