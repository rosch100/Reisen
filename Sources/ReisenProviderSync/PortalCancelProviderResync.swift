import Foundation
import WebKit
import ReisenAppCore
import ReisenDiagnostics
import ReisenDomain
import ReisenProviders
import ReisenSharedUI

/// Quiet single-provider sync after cancel-sheet completion detection.
@MainActor
public enum PortalCancelProviderResync {
    public static let operation = "provider_sync_after_cancel"
    public static let component = "PortalCancelProviderResync"
    public static let phase = "resync"

    /// Clears the sticky completion flag and posts `reisenSyncProvider` when set.
    public static func consumeCompletionAndRequest(
        _ completed: inout Bool,
        providerID: ProviderID
    ) {
        guard completed else { return }
        completed = false
        postRequested(providerID: providerID)
    }

    public static func postRequested(providerID: ProviderID) {
        record(
            providerID: providerID,
            event: "portal_cancel_resync_requested",
            result: .started,
            reason: nil
        )
        NotificationCenter.default.post(name: .reisenSyncProvider, object: providerID)
    }

    /// Resolves optional host dependencies, then runs a single-provider sync.
    public static func run(
        providerID: ProviderID,
        syncStore: SyncStore?,
        sessionHub: ProviderSessionHub?,
        settings: AppSettings
    ) async {
        guard let syncStore else {
            recordHostUnavailable(providerID: providerID, reason: "missing_store")
            return
        }
        guard let sessionHub else {
            recordHostUnavailable(providerID: providerID, reason: "missing_session_hub")
            return
        }
        await runReady(
            providerID: providerID,
            syncStore: syncStore,
            sessionHub: sessionHub,
            settings: settings
        )
    }

    private static func recordHostUnavailable(providerID: ProviderID, reason: String) {
        record(
            providerID: providerID,
            event: "portal_cancel_resync_started",
            result: .failed,
            reason: reason
        )
    }

    private static func runReady(
        providerID: ProviderID,
        syncStore: SyncStore,
        sessionHub: ProviderSessionHub,
        settings: AppSettings
    ) async {
        if syncStore.isSyncing {
            record(
                providerID: providerID,
                event: "portal_cancel_resync_skipped_busy",
                result: .skipped,
                reason: "is_syncing"
            )
            return
        }
        guard let webView = sessionHub.webView(for: providerID) else {
            record(
                providerID: providerID,
                event: "portal_cancel_resync_started",
                result: .failed,
                reason: "missing_webview"
            )
            return
        }
        record(
            providerID: providerID,
            event: "portal_cancel_resync_started",
            result: .started,
            reason: nil
        )
        await syncStore.sync(
            providerID: providerID,
            webView: webView,
            settings: settings,
            navigationHintURLs: NavigationHintURLs.ordered(
                hubURLString: sessionHub.lastURLString(for: providerID)
            ),
            diagnosticContext: DiagnosticContext(
                runID: UUID(),
                providerID: providerID,
                operation: operation
            )
        )
    }

    private static func record(
        providerID: ProviderID,
        event: String,
        result: DiagnosticResult,
        reason: String?
    ) {
        let diagnostic = DiagnosticEvent(
            context: DiagnosticContext(
                runID: UUID(),
                providerID: providerID,
                operation: operation
            ),
            component: component,
            phase: phase,
            event: event,
            result: result,
            reason: reason
        )
        Task {
            await DiagnosticLogger.shared.record(diagnostic)
        }
    }
}
