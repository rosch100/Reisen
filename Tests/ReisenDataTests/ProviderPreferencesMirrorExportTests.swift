import Foundation
import Testing
import SwiftData
import ReisenData
import ReisenDomain

@MainActor
@Suite("ProviderPreferencesMirror export noop")
struct ProviderPreferencesMirrorExportTests {
    @Test func exportSkipsSaveWhenSnapshotUnchanged() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let suite = "reisen.test.prefs.export.noop.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))

        #expect(try ProviderPreferencesMirror.export(from: defaults, into: context) == true)
        #expect(try ProviderPreferencesMirror.export(from: defaults, into: context) == false)

        let record = try ProviderPreferencesMirror.fetchCanonical(in: context)
        #expect(record?.id == ProviderPreferencesRecordID.singleton)
    }

    @Test func exportWritesWhenEnabledSetChanges() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let suite = "reisen.test.prefs.export.change.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
        #expect(try ProviderPreferencesMirror.export(from: defaults, into: context) == true)

        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .booking))
        #expect(try ProviderPreferencesMirror.export(from: defaults, into: context) == true)
    }

    @Test func importApplyingSkipsWhenDefaultsMatch() throws {
        let schema = Schema([SDProviderPreferences.self])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = ModelContext(container)

        let suite = "reisen.test.prefs.import.noop.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: AppSettingsKeys.providerSetupCompleted)
        defaults.set(true, forKey: AppSettingsKeys.providerEnabledKey(for: .check24))
        #expect(try ProviderPreferencesMirror.export(from: defaults, into: context) == true)

        let first = try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
        #expect(first?.setupCompleted == true)
        #expect(context.hasChanges == false)

        let second = try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
        #expect(second == first)
        #expect(context.hasChanges == false)
    }
}
