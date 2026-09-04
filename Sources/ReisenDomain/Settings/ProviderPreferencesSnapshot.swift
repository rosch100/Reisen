import Foundation

/// Feste ID für den CloudKit-Singleton `SDProviderPreferences`.
public enum ProviderPreferencesRecordID: Sendable {
    public static let singleton = UUID(uuidString: "A1B2C3D4-E5F6-4789-A012-3456789ABCDE")!
}

/// Snapshot der geräteübergreifend gespiegelten Provider-Prefs (ohne Secrets, ohne Deferred).
public struct ProviderPreferencesSnapshot: Equatable, Sendable {
    public var setupCompleted: Bool
    public var enabledProviderIDs: Set<ProviderID>

    public init(setupCompleted: Bool, enabledProviderIDs: Set<ProviderID>) {
        self.setupCompleted = setupCompleted
        self.enabledProviderIDs = enabledProviderIDs
    }

    public static func read(
        from defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> ProviderPreferencesSnapshot {
        let enabled = Set(syncProviderIDs.filter { AppSettingsKeys.isProviderEnabled($0, defaults: defaults) })
        return ProviderPreferencesSnapshot(
            setupCompleted: defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted),
            enabledProviderIDs: enabled
        )
    }

    /// Wendet den Snapshot vollständig auf Prefs-Keys an (kein Partial-Merge).
    public func apply(
        to defaults: UserDefaults = AppSettingsDefaults.current,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) {
        defaults.set(setupCompleted, forKey: AppSettingsKeys.providerSetupCompleted)
        ProviderFirstLaunchSetup.applySelection(
            enabledIDs: enabledProviderIDs,
            syncProviderIDs: syncProviderIDs,
            defaults: defaults
        )
    }

    public var enabledProviderRawCSV: String {
        enabledProviderIDs.map(\.rawValue).sorted().joined(separator: ",")
    }

    public static func fromCSV(
        setupCompleted: Bool,
        enabledProviderRawCSV: String,
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs
    ) -> ProviderPreferencesSnapshot {
        let allowed = Set(syncProviderIDs.map(\.rawValue))
        let parts = enabledProviderRawCSV
            .split(separator: ",", omittingEmptySubsequences: true)
            .map(String.init)
        let enabled = Set(
            parts.compactMap { raw -> ProviderID? in
                guard allowed.contains(raw) else { return nil }
                return ProviderID(rawValue: raw)
            }
        )
        return ProviderPreferencesSnapshot(setupCompleted: setupCompleted, enabledProviderIDs: enabled)
    }
}
