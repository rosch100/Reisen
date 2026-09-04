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
        !PersistenceBootstrap.isCloudKitEnabledByEnvironment()
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
            let snap = applyImport(from: context, into: defaults)
            recordPrefsImport(
                result: .succeeded,
                reason: snap == nil ? "gate_immediate_empty" : "gate_immediate"
            )
            return snap
        }

        if let existing = applyImport(from: context, into: defaults),
           existing.setupCompleted {
            recordPrefsImport(result: .succeeded, reason: "gate_already_present")
            return existing
        }

        await PersistenceBootstrap.awaitCloudKitImportIfNeeded(timeout: timeout)

        let snap = applyImport(from: context, into: defaults)
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
            try ProviderPreferencesMirror.export(from: defaults, into: context)
            recordPrefsExport(result: .succeeded, reason: "export")
        } catch {
            recordPrefsExport(result: .failed, reason: "export_failed")
        }
    }

    /// Apply remote prefs; returns snapshot if a record existed.
    /// Kein-op während eigenem Export oder ohne CloudKit-Observer-Kontext.
    public static func applyRemoteChange(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> ProviderPreferencesSnapshot? {
        guard shouldObserveRemoteChanges else { return nil }
        guard !isExporting else { return nil }
        guard !isApplyingRemote else { return nil }
        return applyImport(from: context, into: defaults)
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
    ) -> ProviderPreferencesSnapshot? {
        isApplyingRemote = true
        defer { isApplyingRemote = false }
        return try? ProviderPreferencesMirror.importApplying(from: context, into: defaults)
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
