import Foundation

/// Welche SyncStore-Status-/Fehlermeldungen in welcher Sync-UI-Fläche erscheinen (macOS + iOS).
public enum SyncFeedbackScope: Sendable {
    /// Provider-Chrome (SyncView / SyncTab Action-Bar): nur Meldungen des ausgewählten Providers.
    public static func belongsToSelectedProvider(
        selected: ProviderID,
        isSyncing: Bool,
        syncingProviderID: ProviderID?,
        messageProviderID: ProviderID?
    ) -> Bool {
        if isSyncing {
            return syncingProviderID == selected
        }
        return messageProviderID == selected
    }

    /// Globale Sync-All-/Unscoped-Fläche (`messageProviderID == nil`), nicht der aktuellen WebView zuschreiben.
    public static func showsUnscopedAggregateBanner(messageProviderID: ProviderID?) -> Bool {
        messageProviderID == nil
    }
}
