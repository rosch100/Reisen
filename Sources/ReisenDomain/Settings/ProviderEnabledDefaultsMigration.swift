import Foundation

/// Einmalige Migration: früher fehlender Key = Provider aktiv; neu = opt-in (fehlend = aus).
public enum ProviderEnabledDefaultsMigration: Sendable {
    public static let migratedKey = "reisen_providerEnabledOptInMigrated_v1"
    /// Reparatur: fälschlich materialisiertes All-On ohne vollständige Konten zurücksetzen.
    public static let falsePositiveRepairKey = "reisen_providerEnabledFalsePositiveRepair_v1"
    /// Nach lokalem Repair: Mirror (SwiftData/CloudKit) muss bereinigt werden, sonst Re-Infektion.
    public static let needsMirrorExportKey = "reisen_providerEnabledFalsePositiveNeedsMirrorExport_v1"
    /// Einmalig: Repair-Key zurücksetzen (v2: No-Op-`defer`; v3: All-On trotz partieller Preferred-Konten).
    public static let falsePositiveRepairSemanticsV3Key =
        "reisen_providerEnabledFalsePositiveRepairSemantics_v3"

    /// `true`, wenn dieses Preferred-Konto gesetzt und nicht leer ist.
    public static func hasConfiguredPreferredAccount(
        for providerID: ProviderID,
        defaults: UserDefaults
    ) -> Bool {
        let key = AppSettingsKeys.preferredKeychainAccountKey(for: providerID)
        guard let raw = defaults.string(forKey: key) else { return false }
        return !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// `true`, wenn mindestens ein Sync-Provider ein nicht-leeres Preferred-Konto hat.
    public static func hasConfiguredPreferredAccount(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults
    ) -> Bool {
        syncProviderIDs.contains { hasConfiguredPreferredAccount(for: $0, defaults: defaults) }
    }

    /// Upgrade-Signal: konfiguriertes Provider-Konto (nicht nur beliebige `reisen_*`-UI-Keys).
    public static func looksLikeExistingInstall(defaults: UserDefaults) -> Bool {
        hasConfiguredPreferredAccount(defaults: defaults)
    }

    /// Materialisiert bei Upgrade nur Portale mit Preferred-Konto; übrige bleiben Opt-in.
    @discardableResult
    public static func migrateIfNeeded(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: migratedKey) else { return false }

        if looksLikeExistingInstall(defaults: defaults) {
            for providerID in syncProviderIDs {
                let key = AppSettingsKeys.providerEnabledKey(for: providerID)
                guard defaults.object(forKey: key) == nil else { continue }
                guard hasConfiguredPreferredAccount(for: providerID, defaults: defaults) else {
                    continue
                }
                defaults.set(true, forKey: key)
            }
        }

        defaults.set(true, forKey: migratedKey)
        return true
    }

    /// Erlaubt erneuten False-Positive-Repair inkl. Mirror-Clear nach Heuristik-Wechsel.
    @discardableResult
    public static func migrateFalsePositiveRepairSemanticsV3IfNeeded(
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: falsePositiveRepairSemanticsV3Key) else { return false }
        defaults.set(true, forKey: falsePositiveRepairSemanticsV3Key)
        defaults.removeObject(forKey: falsePositiveRepairKey)
        defaults.removeObject(forKey: needsMirrorExportKey)
        // Legacy v2-Flag belassen falls gesetzt — v3 ist die autoritative Reset-Stufe.
        return true
    }

    /// Entfernt Enable-Keys sowie Setup-Completed/Deferred (Frischstart-Opt-in, Sheet wieder möglich).
    public static func resetToOptInClearingSetup(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = .standard
    ) {
        for providerID in syncProviderIDs {
            defaults.removeObject(forKey: AppSettingsKeys.providerEnabledKey(for: providerID))
        }
        defaults.removeObject(forKey: AppSettingsKeys.providerSetupCompleted)
        defaults.removeObject(forKey: AppSettingsKeys.providerSetupDeferred)
    }

    /// All-On ist False-Positive, wenn nicht jedes Portal ein Preferred-Konto hat
    /// (Migrate-/Mirror-All-On trotz nur partieller Konten).
    public static func isFalsePositiveAllOn(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults
    ) -> Bool {
        guard !syncProviderIDs.isEmpty else { return false }
        let allEnabled = syncProviderIDs.allSatisfy { providerID in
            AppSettingsKeys.isProviderEnabled(providerID, defaults: defaults)
        }
        guard allEnabled else { return false }
        return !syncProviderIDs.allSatisfy { providerID in
            hasConfiguredPreferredAccount(for: providerID, defaults: defaults)
        }
    }

    /// Setzt False-Positive-All-On zurück auf Opt-in und öffnet das Erststart-Setup erneut.
    @discardableResult
    public static func repairFalsePositiveAllOnIfNeeded(
        syncProviderIDs: [ProviderID] = ProviderID.syncProviderIDs,
        defaults: UserDefaults = .standard
    ) -> Bool {
        guard !defaults.bool(forKey: falsePositiveRepairKey) else { return false }
        guard defaults.bool(forKey: migratedKey) else { return false }
        guard isFalsePositiveAllOn(syncProviderIDs: syncProviderIDs, defaults: defaults) else {
            return false
        }

        resetToOptInClearingSetup(syncProviderIDs: syncProviderIDs, defaults: defaults)
        defaults.set(true, forKey: falsePositiveRepairKey)
        defaults.set(true, forKey: needsMirrorExportKey)
        return true
    }
}
