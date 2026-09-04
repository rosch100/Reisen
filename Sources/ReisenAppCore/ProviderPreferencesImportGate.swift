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
            let snap = try? ProviderPreferencesMirror.importApplying(from: context, into: defaults)
            recordPrefsImport(
                result: .succeeded,
                reason: snap == nil ? "gate_immediate_empty" : "gate_immediate"
            )
            return snap
        }

        if let existing = try? ProviderPreferencesMirror.importApplying(from: context, into: defaults),
           existing.setupCompleted {
            recordPrefsImport(result: .succeeded, reason: "gate_already_present")
            return existing
        }

        await PersistenceBootstrap.awaitCloudKitImportIfNeeded(timeout: timeout)

        let snap = try? ProviderPreferencesMirror.importApplying(from: context, into: defaults)
        if snap == nil {
            recordPrefsImport(result: .timedOut, reason: "gate_timeout_empty")
        } else {
            recordPrefsImport(result: .succeeded, reason: "gate_after_wait")
        }
        return snap
    }

    public static func exportFromDefaults(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) {
        do {
            try ProviderPreferencesMirror.export(from: defaults, into: context)
            recordPrefsExport(result: .succeeded, reason: "export")
        } catch {
            recordPrefsExport(result: .failed, reason: "export_failed")
        }
    }

    /// Apply remote prefs; returns snapshot if a record existed.
    public static func applyRemoteChange(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> ProviderPreferencesSnapshot? {
        try? ProviderPreferencesMirror.importApplying(from: context, into: defaults)
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
