import Foundation
import ReisenDomain
import ReisenDiagnostics

#if canImport(UIKit) && !os(watchOS)
import UIKit
#endif

/// Wendet `AppIconStyle` auf das Homescreen-Icon an (iOS Alternate Icons).
@MainActor
public enum AppIconApplicator {
    private static var diagnosticContext: DiagnosticContext {
        DiagnosticContext(
            runID: UUID(),
            providerID: .manual,
            operation: "app_icon"
        )
    }

    public static func applyStoredPreference(defaults: UserDefaults = .standard) async {
        let style = AppIconStyle.from(stored: defaults.string(forKey: AppSettingsKeys.appIconStyle))
        _ = await apply(style)
    }

    /// - Returns: `true` wenn angewandt, unverändert oder plattformseitig übersprungen; `false` bei Fehler.
    @discardableResult
    public static func apply(_ style: AppIconStyle) async -> Bool {
        #if os(iOS)
        guard UIApplication.shared.supportsAlternateIcons else {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "AppIconApplicator",
                    phase: "apply",
                    event: "unsupported",
                    result: .skipped,
                    reason: "alternate_icons_unsupported",
                    visibility: .publicDiagnostic
                )
            )
            return true
        }

        let desired = style.alternateIconName
        let current = UIApplication.shared.alternateIconName
        guard desired != current else {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "AppIconApplicator",
                    phase: "apply",
                    event: "unchanged",
                    result: .skipped,
                    reason: style.rawValue,
                    visibility: .localDebugOnly
                )
            )
            return true
        }

        await DiagnosticLogger.shared.record(
            DiagnosticEvent(
                context: diagnosticContext,
                component: "AppIconApplicator",
                phase: "apply",
                event: "started",
                result: .started,
                reason: style.rawValue,
                visibility: .publicDiagnostic
            )
        )

        do {
            try await UIApplication.shared.setAlternateIconName(desired)
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "AppIconApplicator",
                    phase: "apply",
                    event: "succeeded",
                    result: .succeeded,
                    reason: style.rawValue,
                    visibility: .publicDiagnostic
                )
            )
            return true
        } catch {
            await DiagnosticLogger.shared.record(
                DiagnosticEvent(
                    context: diagnosticContext,
                    component: "AppIconApplicator",
                    phase: "apply",
                    event: "failed",
                    result: .failed,
                    reason: "set_alternate_icon_failed",
                    visibility: .publicDiagnostic
                )
            )
            return false
        }
        #else
        return true
        #endif
    }
}
