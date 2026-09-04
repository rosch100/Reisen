import Foundation

/// Einmalige Migration: früher fehlender Key = Provider aktiv; neu = opt-in (fehlend = aus).
public enum ProviderEnabledDefaultsMigration: Sendable {
    public static let migratedKey = "reisen_providerEnabledOptInMigrated_v1"
    /// Reparatur: fälschlich materialisiertes All-On ohne konfigurierte Konten zurücksetzen.
    public static let falsePositiveRepairKey = "reisen_providerEnabledFalsePositiveRepair_v1"

    /// `true`, wenn mindestens ein Sync-Provider ein nicht-leeres Preferred-Konto hat.
    public static func hasConfiguredPreferredAccount(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults
    ) -> Bool {
        syncProviderIDs.contains { providerID in
            let key = AppSettingsKeys.preferredKeychainAccountKey(for: providerID)
            guard let raw = defaults.string(forKey: key) else { return false }
            return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    /// Upgrade-Signal: konfiguriertes Provider-Konto (nicht nur beliebige `reisen_*`-UI-Keys).
    public static func looksLikeExistingInstall(defaults: UserDefaults) -> Bool {
        hasConfiguredPreferredAccount(defaults: defaults)
    }

    /// Materialisiert bei echtem Pre-Opt-in-Upgrade die frühere Default-Wahrheit; sonst Opt-in.
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

    /// Setzt All-On ohne Preferred-Konto zurück auf Opt-in und öffnet das Erststart-Setup erneut.
    @discardableResult
    public static func repairFalsePositiveAllOnIfNeeded(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: falsePositiveRepairKey) else { return false }
        defer { defaults.set(true, forKey: falsePositiveRepairKey) }

        guard defaults.bool(forKey: migratedKey) else { return false }
        guard !hasConfiguredPreferredAccount(syncProviderIDs: syncProviderIDs, defaults: defaults) else {
            return false
        }
        guard !syncProviderIDs.isEmpty else { return false }
        let allEnabled = syncProviderIDs.allSatisfy { providerID in
            AppSettingsKeys.isProviderEnabled(providerID, defaults: defaults)
        }
        guard allEnabled else { return false }

        for providerID in syncProviderIDs {
            defaults.removeObject(forKey: AppSettingsKeys.providerEnabledKey(for: providerID))
        }
        defaults.removeObject(forKey: AppSettingsKeys.providerSetupCompleted)
        return true
    }
}
