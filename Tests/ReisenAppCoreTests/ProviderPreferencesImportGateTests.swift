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

    @Test("applyRemoteChange returns nil when mirror matches defaults")
    func applyRemoteChangeSkipsWhenUnchanged() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let suiteName = "test.prefs.gate.remote.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        suite.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
        suite.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
        #expect(try ProviderPreferencesMirror.export(from: suite, into: context) == true)

        let applied = ProviderPreferencesImportGate.applyRemoteChange(context: context, defaults: suite)
        #expect(applied == nil)
    }
}
