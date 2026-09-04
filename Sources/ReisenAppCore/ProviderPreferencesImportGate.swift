import Foundation
import SwiftData
import ReisenDomain
import ReisenDiagnostics
import ReisenData

/// Wartet auf initialen Prefs-Import und wendet Snapshot an; UITesting/CloudKit-off → sofort.
@MainActor
public enum ProviderPreferencesImportGate {
    public static let defaultTimeout: Duration = .seconds(8)

    /// Reentrancy: eigener Export darf keinen Remote-Apply-Loop auslösen; Import kein Re-Export.
    private static var isExporting = false
    private static var isApplyingRemote = false
    /// Nach Import→notify: Exporte unterdrücken, bis SwiftUI-`onChange`-Handler gelaufen sind.
    private static var suppressExportsAfterImportNotify = false

    public static var shouldSkipCloudKitWait: Bool {
        !PersistenceBootstrap.isCloudKitEnabledByEnvironment(
            iCloudSyncPreferenceEnabled: AppSettingsKeys.isICloudSyncEnabled()
        )
            || UITestingLaunch.isActive
    }

    /// Remote-Change-Observer nur bei echtem CloudKit (nicht UITesting / CloudKit-off).
    public static var shouldObserveRemoteChanges: Bool {
        !shouldSkipCloudKitWait
    }

    /// - Returns: angewandter Snapshot falls Prefs-Record vorhanden; sonst nil.
    @discardableResult
    public static func awaitAndApply(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current,
        timeout: Duration = defaultTimeout
    ) async -> ProviderPreferencesSnapshot? {
        recordPrefsImport(result: .started, reason: "gate_start")

        if shouldSkipCloudKitWait {
            do {
                let snap = try applyImport(from: context, into: defaults)
                if clearPoisonedMirrorAfterFalsePositiveRepairIfNeeded(
                    context: context,
                    defaults: defaults
                ) {
                    return nil
                }
                recordPrefsImport(
                    result: .succeeded,
                    reason: snap == nil ? "gate_immediate_empty" : "gate_immediate"
                )
                return snap
            } catch {
                recordPrefsImport(result: .failed, reason: "gate_immediate_import_failed")
                return nil
            }
        }

        do {
            if let existing = try applyImport(from: context, into: defaults),
               existing.setupCompleted {
                if clearPoisonedMirrorAfterFalsePositiveRepairIfNeeded(
                    context: context,
                    defaults: defaults
                ) {
                    return nil
                }
                recordPrefsImport(result: .succeeded, reason: "gate_already_present")
                return existing
            }
        } catch {
            recordPrefsImport(result: .failed, reason: "gate_precheck_import_failed")
            return nil
        }

        await PersistenceBootstrap.awaitCloudKitImportIfNeeded(
            timeout: timeout,
            cloudKitEnabled: true
        )

        do {
            let snap = try applyImport(from: context, into: defaults)
            if clearPoisonedMirrorAfterFalsePositiveRepairIfNeeded(
                context: context,
                defaults: defaults
            ) {
                return nil
            }
            if snap == nil {
                recordPrefsImport(result: .timedOut, reason: "gate_timeout_empty")
            } else {
                recordPrefsImport(result: .succeeded, reason: "gate_after_wait")
            }
            return snap
        } catch {
            recordPrefsImport(result: .failed, reason: "gate_after_wait_import_failed")
            return nil
        }
    }

    public static func exportFromDefaults(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) {
        // UITesting: In-Memory ohne CloudKit — Mirror-Save würde Remote-Change/AX-Idle stören.
        guard !UITestingLaunch.isActive else { return }
        if suppressExportsAfterImportNotify {
            suppressExportsAfterImportNotify = false
            return
        }
        guard !isApplyingRemote else { return }
        isExporting = true
        defer { isExporting = false }
        do {
            let didWrite = try ProviderPreferencesMirror.export(from: defaults, into: context)
            if didWrite {
                recordPrefsExport(result: .succeeded, reason: "export")
            } else {
                recordPrefsExport(result: .skipped, reason: "export_unchanged")
            }
        } catch {
            recordPrefsExport(
                result: .failed,
                reason: "export_failed_\(String(describing: type(of: error)))"
            )
        }
    }

    /// Apply remote prefs; returns snapshot nur wenn lokale Defaults sich geändert haben (sonst kein Notify-Echo).
    /// Kein-op während eigenem Export oder ohne CloudKit-Observer-Kontext.
    public static func applyRemoteChange(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> ProviderPreferencesSnapshot? {
        guard shouldObserveRemoteChanges else { return nil }
        guard !isExporting else { return nil }
        guard !isApplyingRemote else { return nil }
        do {
            let before = ProviderPreferencesSnapshot.read(from: defaults)
            let snap = try applyImport(from: context, into: defaults)
            if clearPoisonedMirrorAfterFalsePositiveRepairIfNeeded(
                context: context,
                defaults: defaults
            ) {
                return nil
            }
            guard let snap else { return nil }
            guard snap != before else { return nil }
            return snap
        } catch {
            recordPrefsImport(result: .failed, reason: "remote_apply_import_failed")
            return nil
        }
    }

    /// UI nach Import aktualisieren, ohne den Mirror erneut zu exportieren.
    ///
    /// `onProviderEnabledChange(bump:perform:)` exportiert oft erst im SwiftUI-`onChange`
    /// (nicht synchron in `NotificationCenter`). Das Flag wird vom ersten Export-Versuch
    /// verbraucht; doppeltes `async` räumt es sonst nach dem UI-Update wieder ab.
    public static func notifyEnabledAfterImport() {
        suppressExportsAfterImportNotify = true
        ProviderEnabledChange.notify()
        DispatchQueue.main.async {
            DispatchQueue.main.async {
                suppressExportsAfterImportNotify = false
            }
        }
    }

    private static func applyImport(
        from context: ModelContext,
        into defaults: UserDefaults
    ) throws -> ProviderPreferencesSnapshot? {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        return try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
    }

    /// Nach lokalem False-Positive-Repair: Import darf den Mirror-Poison nicht dauerhaft zurückschreiben.
    /// - Returns: `true`, wenn Mirror bereinigt wurde (Caller soll Snapshot verwerfen).
    @discardableResult
    private static func clearPoisonedMirrorAfterFalsePositiveRepairIfNeeded(
        context: ModelContext,
        defaults: UserDefaults
    ) -> Bool {
        let needsExport = defaults.bool(forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)
        let reinfectedAfterRepair =
            defaults.bool(forKey: ProviderEnabledDefaultsMigration.falsePositiveRepairKey)
            && ProviderEnabledDefaultsMigration.isFalsePositiveAllOn(defaults: defaults)

        guard needsExport || reinfectedAfterRepair else {
            return false
        }

        ProviderEnabledDefaultsMigration.resetToOptInClearingSetup(defaults: defaults)
        do {
            try ProviderPreferencesMirror.deleteAll(in: context)
            defaults.set(false, forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)
            recordPrefsImport(
                result: .succeeded,
                reason: needsExport
                    ? "false_positive_mirror_cleared"
                    : "false_positive_mirror_reinfection_cleared"
            )
            return true
        } catch {
            recordPrefsImport(result: .failed, reason: "false_positive_mirror_clear_failed")
            return true
        }
    }

    private static func recordPrefsImport(result: DiagnosticResult, reason: String) {
        ProviderFirstLaunchSetupDiagnostics.record(
            event: "prefs_import",
            result: result,
            reason: reason
        )
    }

    private static func recordPrefsExport(result: DiagnosticResult, reason: String) {
        ProviderFirstLaunchSetupDiagnostics.record(
            event: "prefs_export",
            result: result,
            reason: reason
        )
    }
}
