import Foundation
import SwiftData
import ReisenDomain
import ReisenDiagnostics
import ReisenData

/// Ergebnis des Prefs-Imports — Fehler sind nie „wie kein Record“.
public enum PrefsImportOutcome: Equatable, Sendable {
    case applied(ProviderPreferencesSnapshot)
    case noRecord
    case failed
}

/// Ergebnis des Startup-Gates: Cloud-Prefs fertig vs. lokale Setup-UI fortsetzen.
public enum PrefsStartupGateResult: Equatable, Sendable {
    /// Remote/local prefs mit `setupCompleted` — kein First-Launch-Sheet.
    case setupCompletedFromCloud
    /// Kein fertiges Cloud-Snapshot (oder Seed) — Caller darf Setup-UI zeigen.
    case continueLocalSetup
}

/// Wartet auf initialen Prefs-Import und wendet Snapshot an; UITesting/CloudKit-off → sofort.
@MainActor
public enum ProviderPreferencesImportGate {
    public static let defaultTimeout: Duration = .seconds(8)

    /// Test-only: static Gate-Flags zwischen Suites zurücksetzen (Shared MainActor-State).
    static func resetGateStateForTests() {
        isExporting = false
        isApplyingRemote = false
        suppressExportsAfterImportNotify = false
    }

    private enum PoisonClearResult {
        case notNeeded
        case cleared
        case failed
    }

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

    /// Import mit Fail-closed Outcome (`.failed` ≠ `.noRecord`).
    @discardableResult
    public static func awaitAndApply(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current,
        timeout: Duration = defaultTimeout
    ) async -> PrefsImportOutcome {
        recordPrefsImport(result: .started, reason: "gate_start")

        if purgePoisonedMirrorPreferringLocalDefaults(context: context, defaults: defaults) == .failed {
            return .failed
        }

        if shouldSkipCloudKitWait {
            return outcomeAfterImportAttempt(
                context: context,
                defaults: defaults,
                successReasonIfPresent: "gate_immediate",
                emptyReason: "gate_immediate_empty",
                emptyResult: .succeeded,
                failureReason: "gate_immediate_import_failed"
            )
        }

        do {
            if let existing = try applyImport(from: context, into: defaults),
               existing.setupCompleted {
                recordPrefsImport(result: .succeeded, reason: "gate_already_present")
                return .applied(existing)
            }
        } catch {
            recordPrefsImport(result: .failed, reason: "gate_precheck_import_failed")
            return .failed
        }

        let awaitResult = await PersistenceBootstrap.awaitCloudKitImportIfNeeded(
            timeout: timeout,
            cloudKitEnabled: true
        )
        if awaitResult == .timedOut {
            recordPrefsImport(result: .timedOut, reason: "gate_cloudkit_wait_timed_out")
        }

        return outcomeAfterImportAttempt(
            context: context,
            defaults: defaults,
            successReasonIfPresent: "gate_after_wait",
            emptyReason: awaitResult == .timedOut ? "gate_timeout_empty" : "gate_after_wait_empty",
            emptyResult: awaitResult == .timedOut ? .timedOut : .skipped,
            failureReason: "gate_after_wait_import_failed"
        )
    }

    /// macOS/iOS Startup: Import → ggf. lokales Seed bei `.noRecord` → ob Setup-UI folgen soll.
    @discardableResult
    public static func awaitApplyAndSeedLocalIfEmpty(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current,
        timeout: Duration = defaultTimeout
    ) async -> PrefsStartupGateResult {
        let outcome = await awaitAndApply(context: context, defaults: defaults, timeout: timeout)
        if case .applied(let snap) = outcome, snap.setupCompleted {
            ProviderFirstLaunchSetupDiagnostics.recordSkipped(reason: "icloud_prefs")
            notifyEnabledAfterImport()
            return .setupCompletedFromCloud
        }
        // Seed CloudKit only when no remote prefs arrived — never overwrite on import failure.
        if case .noRecord = outcome,
           defaults.bool(forKey: AppSettingsKeys.providerSetupCompleted) {
            exportFromDefaults(context: context, defaults: defaults)
        }
        return .continueLocalSetup
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
    /// Import-Fehler → nil + Diagnostic `.failed` (nie still wie „kein Record“ ohne Event).
    public static func applyRemoteChange(
        context: ModelContext,
        defaults: UserDefaults = AppSettingsDefaults.current
    ) -> ProviderPreferencesSnapshot? {
        guard shouldObserveRemoteChanges else { return nil }
        guard !isExporting else { return nil }
        guard !isApplyingRemote else { return nil }
        if purgePoisonedMirrorPreferringLocalDefaults(context: context, defaults: defaults) == .failed {
            return nil
        }
        do {
            let before = ProviderPreferencesSnapshot.read(from: defaults)
            let snap = try applyImport(from: context, into: defaults)
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

    private static func outcomeAfterImportAttempt(
        context: ModelContext,
        defaults: UserDefaults,
        successReasonIfPresent: String,
        emptyReason: String,
        emptyResult: DiagnosticResult,
        failureReason: String
    ) -> PrefsImportOutcome {
        do {
            let snap = try applyImport(from: context, into: defaults)
            if let snap {
                recordPrefsImport(result: .succeeded, reason: successReasonIfPresent)
                return .applied(snap)
            }
            recordPrefsImport(result: emptyResult, reason: emptyReason)
            return .noRecord
        } catch {
            recordPrefsImport(result: .failed, reason: failureReason)
            return .failed
        }
    }

    /// Vor jedem Import: vergifteten Mirror löschen und **lokale** Defaults exportieren.
    /// Kein `resetToOptIn` — Repair/User-Setup sind bereits lokal autoritativ.
    @discardableResult
    private static func purgePoisonedMirrorPreferringLocalDefaults(
        context: ModelContext,
        defaults: UserDefaults
    ) -> PoisonClearResult {
        let needsExport = defaults.bool(forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)
        guard needsExport else {
            return .notNeeded
        }

        do {
            try ProviderPreferencesMirror.deleteAll(in: context)
            isExporting = true
            defer { isExporting = false }
            _ = try ProviderPreferencesMirror.export(from: defaults, into: context)
            defaults.set(false, forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)
            recordPrefsImport(
                result: .succeeded,
                reason: "false_positive_mirror_cleared"
            )
            recordPrefsExport(result: .succeeded, reason: "false_positive_clean_export")
            return .cleared
        } catch {
            defaults.set(true, forKey: ProviderEnabledDefaultsMigration.needsMirrorExportKey)
            recordPrefsImport(result: .failed, reason: "false_positive_mirror_clear_failed")
            return .failed
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
