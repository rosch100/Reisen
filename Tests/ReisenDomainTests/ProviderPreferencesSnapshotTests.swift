import Testing
import Foundation
import ReisenDomain

@Suite("ProviderPreferencesSnapshot")
struct ProviderPreferencesSnapshotTests {
    @Test("read/apply round-trip sets setupCompleted and enables explicitly")
    func roundTrip() {
        let suiteName = "test.prefs.snapshot.\(UUID().uuidString)"
        let suite = UserDefaults(suiteName: suiteName)!
        defer { suite.removePersistentDomain(forName: suiteName) }

        let syncIDs = [ProviderID.opodo, ProviderID.booking]
        ProviderFirstLaunchSetup.applySelection(
            enabledIDs: [ProviderID.opodo],
            syncProviderIDs: syncIDs,
            defaults: suite
        )
        ProviderFirstLaunchSetup.markCompleted(defaults: suite)

        let snap = ProviderPreferencesSnapshot.read(from: suite, syncProviderIDs: syncIDs)
        #expect(snap.setupCompleted)
        #expect(snap.enabledProviderIDs == [ProviderID.opodo])
        #expect(snap.enabledProviderRawCSV == "opodo")

        let suiteBName = "test.prefs.snapshot.b.\(UUID().uuidString)"
        let suiteB = UserDefaults(suiteName: suiteBName)!
        defer { suiteB.removePersistentDomain(forName: suiteBName) }
        snap.apply(to: suiteB, syncProviderIDs: syncIDs)
        #expect(suiteB.bool(forKey: AppSettingsKeys.providerSetupCompleted))
        #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: suiteB))
        #expect(!AppSettingsKeys.isProviderEnabled(.booking, defaults: suiteB))
    }

    @Test("fromCSV ignores unknown provider raw values")
    func fromCSVIgnoresUnknown() {
        let snap = ProviderPreferencesSnapshot.fromCSV(
            setupCompleted: true,
            enabledProviderRawCSV: "opodo,not-a-provider,booking",
            syncProviderIDs: [ProviderID.opodo, ProviderID.booking]
        )
        #expect(snap.enabledProviderIDs == [ProviderID.opodo, ProviderID.booking])
    }

    @Test("singleton ID is stable")
    func singletonID() {
        #expect(ProviderPreferencesRecordID.singleton.uuidString == "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")
    }
}
