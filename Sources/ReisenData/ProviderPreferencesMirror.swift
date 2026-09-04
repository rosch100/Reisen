import Foundation
import SwiftData
import ReisenDomain

/// Export/Import zwischen UserDefaults (Runtime-SSOT) und CloudKit-Singleton.
@MainActor
public enum ProviderPreferencesMirror {
    public static func export(
        from defaults: UserDefaults = AppSettingsDefaults.current,
        into context: ModelContext
    ) throws {
        let snapshot = ProviderPreferencesSnapshot.read(from: defaults)
        let record = try upsertSingleton(in: context)
        record.setupCompleted = snapshot.setupCompleted
        record.enabledProviderRawCSV = snapshot.enabledProviderRawCSV
        dedupeNonCanonical(in: context, keeping: record)
        try context.save()
    }

    /// Liest Singleton (falls vorhanden), wendet auf Defaults an, räumt Duplikate auf.
    @discardableResult
    public static func importApplying(
        from context: ModelContext,
        into defaults: UserDefaults = AppSettingsDefaults.current
    ) throws -> ProviderPreferencesSnapshot? {
        guard let record = try fetchCanonical(in: context) else { return nil }
        dedupeNonCanonical(in: context, keeping: record)
        let snapshot = ProviderPreferencesSnapshot.fromCSV(
            setupCompleted: record.setupCompleted,
            enabledProviderRawCSV: record.enabledProviderRawCSV
        )
        snapshot.apply(to: defaults)
        try context.save()
        return snapshot
    }

    public static func fetchCanonical(in context: ModelContext) throws -> SDProviderPreferences? {
        let singletonID = ProviderPreferencesRecordID.singleton
        let descriptor = FetchDescriptor<SDProviderPreferences>(
            predicate: #Predicate { $0.id == singletonID }
        )
        if let match = try context.fetch(descriptor).first {
            return match
        }
        let all = FetchDescriptor<SDProviderPreferences>()
        return try context.fetch(all).first
    }

    private static func upsertSingleton(in context: ModelContext) throws -> SDProviderPreferences {
        if let existing = try fetchCanonical(in: context) {
            existing.id = ProviderPreferencesRecordID.singleton
            return existing
        }
        let created = SDProviderPreferences()
        context.insert(created)
        return created
    }

    private static func dedupeNonCanonical(in context: ModelContext, keeping canonical: SDProviderPreferences) {
        let all = (try? context.fetch(FetchDescriptor<SDProviderPreferences>())) ?? []
        for row in all where row !== canonical {
            context.delete(row)
        }
        canonical.id = ProviderPreferencesRecordID.singleton
    }
}
