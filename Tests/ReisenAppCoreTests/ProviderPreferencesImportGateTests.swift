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
}
