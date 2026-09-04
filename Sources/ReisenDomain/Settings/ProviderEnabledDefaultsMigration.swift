import Foundation

/// Einmalige Migration: früher fehlender Key = Provider aktiv; neu = opt-in (fehlend = aus).
public enum ProviderEnabledDefaultsMigration: Sendable {
    public static let migratedKey = "reisen_providerEnabledOptInMigrated_v1"

    /// `true`, wenn diese Suite mindestens ein Reisen-Settings-Signal außer dem Migrationsflag trägt.
    public static func looksLikeExistingInstall(defaults: UserDefaults) -> Bool {
        let keys = defaults.dictionaryRepresentation().keys
        return keys.contains { key in
            key.hasPrefix("reisen_") && key != migratedKey
        }
    }

    /// Materialisiert bei Upgrade die frühere Default-Wahrheit; Frischinstall bleibt opt-in.
    @discardableResult
    public static func migrateIfNeeded(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: migratedKey) else { return false }

        if looksLikeExistingInstall(defaults: defaults) {
            for providerID in syncProviderIDs {
                let key = AppSettingsKeys.providerEnabledKey(for: providerID)
                if defaults.object(forKey: key) == nil {
                    defaults.set(true, forKey: key)
                }
            }
        }

        defaults.set(true, forKey: migratedKey)
        return true
    }
}
