import Foundation
import SwiftData
import ReisenDomain
import ReisenDiagnostics
import ReisenData

/// Wartet auf initialen Prefs-Import und wendet Snapshot an; UITesting/CloudKit-off → sofort.
@MainActor
public enum ProviderPreferencesImportGate {
    public static let defaultTimeout: Duration = .seconds(8)

    public static var shouldSkipCloudKitWait: Bool {
        !PersistenceBootstrap.isCloudKitEnabledByEnvironment()
            || UITestingLaunch.isActive
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
                let snap = try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
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
            if let existing = try ProviderPreferencesMirror.importApplying(from: context, into: defaults),
               existing.setupCompleted {
                recordPrefsImport(result: .succeeded, reason: "gate_already_present")
                return existing
            }
        } catch {
            recordPrefsImport(result: .failed, reason: "gate_precheck_import_failed")
            return nil
        }

        await PersistenceBootstrap.awaitCloudKitImportIfNeeded(timeout: timeout)

        do {
            let snap = try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
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
        do {
            try ProviderPreferencesMirror.export(from: defaults, into: context)
            recordPrefsExport(result: .succeeded, reason: "export")
        } catch {
            recordPrefsExport(
                result: .failed,
                reason: "export_failed_\(String(describing: type(of: error)))"
            )
        }
    }

    /// Apply remote prefs; returns snapshot if a record existed.
    public static func applyRemoteChange(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> ProviderPreferencesSnapshot? {
        do {
            return try ProviderPreferencesMirror.importApplying(from: context, into: defaults)
        } catch {
            recordPrefsImport(result: .failed, reason: "remote_apply_import_failed")
            return nil
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
