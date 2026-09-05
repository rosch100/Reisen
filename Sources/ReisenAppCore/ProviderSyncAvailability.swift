import Foundation

/// SSOT-Predicate für SyncView-Toolbar und App-Menü „Aktuelles Portal aktualisieren“.
public enum ProviderSyncAvailability {
    public static func canSync(
        isProviderEnabled: Bool,
        hasWebView: Bool,
        hasRegistry: Bool,
        hasStore: Bool,
        isSyncing: Bool
    ) -> Bool {
        isProviderEnabled
            && hasWebView
            && hasRegistry
            && hasStore
            && !isSyncing
    }
}
