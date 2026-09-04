import Testing
import Foundation
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Suite("ProviderPreferencesMirror")
struct ProviderPreferencesMirrorTests {
    @Test("export then import on second container applies snapshot")
    func exportImportAcrossContainers() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent(
            "reisen-prefs-\(UUID().uuidString)",
            isDirectory: true
        )
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let sharedCloud = root.appendingPathComponent("shared-cloud.sqlite")
        let localA = root.appendingPathComponent("local-a.sqlite")
        let localB = root.appendingPathComponent("local-b.sqlite")

        let suiteAName = "test.prefs.mirror.a.\(UUID().uuidString)"
        let suiteA = UserDefaults(suiteName: suiteAName)!
        defer { suiteA.removePersistentDomain(forName: suiteAName) }
        let syncIDs = ProviderID.syncProviderIDs
        ProviderFirstLaunchSetup.applySelection(
            enabledIDs: [ProviderID.check24, ProviderID.opodo],
            syncProviderIDs: syncIDs,
            defaults: suiteA
        )
        ProviderFirstLaunchSetup.markCompleted(defaults: suiteA)

        let deviceA = try PersistenceBootstrap.makeDualContainer(
            cloudStoreURL: sharedCloud,
            localStoreURL: localA
        )
        try ProviderPreferencesMirror.export(from: suiteA, into: deviceA.mainContext)

        let deviceB = try PersistenceBootstrap.makeDualContainer(
            cloudStoreURL: sharedCloud,
            localStoreURL: localB
        )
        let suiteBName = "test.prefs.mirror.b.\(UUID().uuidString)"
        let suiteB = UserDefaults(suiteName: suiteBName)!
        defer { suiteB.removePersistentDomain(forName: suiteBName) }

        let snap = try ProviderPreferencesMirror.importApplying(
            from: deviceB.mainContext,
            into: suiteB
        )
        #expect(snap?.setupCompleted == true)
        #expect(AppSettingsKeys.isProviderEnabled(.check24, defaults: suiteB))
        #expect(AppSettingsKeys.isProviderEnabled(.opodo, defaults: suiteB))

        let record = try ProviderPreferencesMirror.fetchCanonical(in: deviceB.mainContext)
        #expect(record?.id == ProviderPreferencesRecordID.singleton)
    }
}
