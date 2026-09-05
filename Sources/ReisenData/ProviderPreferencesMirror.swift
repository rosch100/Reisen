import Foundation
import SwiftData
import ReisenDomain

/// Export/Import zwischen UserDefaults (Runtime-SSOT) und CloudKit-Singleton.
@MainActor
public enum ProviderPreferencesMirror {
    /// - Returns: `true` wenn gespeichert; `false` wenn Mirror bereits kanonisch und inhaltlich gleich.
    @discardableResult
    public static func export(
        from defaults: UserDefaults = AppSettingsDefaults.current,
        into context: ModelContext
    ) throws -> Bool {
        let snapshot = ProviderPreferencesSnapshot.read(from: defaults)
        if let existing = try fetchCanonical(in: context),
           existing.setupCompleted == snapshot.setupCompleted,
           existing.enabledProviderRawCSV == snapshot.enabledProviderRawCSV {
            let all = try context.fetch(FetchDescriptor<SDProviderPreferences>())
            let alreadyCanonical =
                existing.id == ProviderPreferencesRecordID.singleton && all.count == 1
            if alreadyCanonical {
                return false
            }
        }
        let record = try upsertSingleton(in: context)
        record.setupCompleted = snapshot.setupCompleted
        record.enabledProviderRawCSV = snapshot.enabledProviderRawCSV
        try dedupeNonCanonical(in: context, keeping: record)
        try context.save()
        return true
    }

    /// Liest Singleton (falls vorhanden), wendet auf Defaults an, räumt Duplikate auf.
    /// - Returns: Snapshot wenn Prefs-Record existiert; `nil` wenn keiner.
    ///   Unveränderte Prefs → kein `apply`/`save` (kein CloudKit-/Notify-Echo).
    @discardableResult
    public static func importApplying(
        from context: ModelContext,
        into defaults: UserDefaults = AppSettingsDefaults.current
    ) throws -> ProviderPreferencesSnapshot? {
        guard let record = try fetchCanonical(in: context) else { return nil }
        let snapshot = ProviderPreferencesSnapshot.fromCSV(
            setupCompleted: record.setupCompleted,
            enabledProviderRawCSV: record.enabledProviderRawCSV
        )
        let current = ProviderPreferencesSnapshot.read(from: defaults)
        if snapshot == current {
            return snapshot
        }
        try dedupeNonCanonical(in: context, keeping: record)
        snapshot.apply(to: defaults)
        try context.save()
        return snapshot
    }

    /// Nur der kanonische Singleton-Record — kein Fallback auf `all.first`.
    public static func fetchCanonical(in context: ModelContext) throws -> SDProviderPreferences? {
        let singletonID = ProviderPreferencesRecordID.singleton
        let descriptor = FetchDescriptor<SDProviderPreferences>(
            predicate: #Predicate { $0.id == singletonID }
        )
        return try context.fetch(descriptor).first
    }

    /// Entfernt alle Prefs-Records (False-Positive-Poison / Mirror-Bereinigung nach lokalem Repair).
    public static func deleteAll(in context: ModelContext) throws {
        let all = try context.fetch(FetchDescriptor<SDProviderPreferences>())
        guard !all.isEmpty else { return }
        for row in all {
            context.delete(row)
        }
        try context.save()
    }

    private static func upsertSingleton(in context: ModelContext) throws -> SDProviderPreferences {
        if let existing = try fetchCanonical(in: context) {
            return existing
        }
        // Export schreibt immer aus Defaults — stray Rows verwerfen, nie Inhalt aus `all.first` übernehmen.
        let all = try context.fetch(FetchDescriptor<SDProviderPreferences>())
        for row in all {
            context.delete(row)
        }
        let created = SDProviderPreferences()
        context.insert(created)
        return created
    }

    private static func dedupeNonCanonical(
        in context: ModelContext,
        keeping canonical: SDProviderPreferences
    ) throws {
        let all = try context.fetch(FetchDescriptor<SDProviderPreferences>())
        for row in all where row !== canonical {
            context.delete(row)
        }
        canonical.id = ProviderPreferencesRecordID.singleton
    }
}
