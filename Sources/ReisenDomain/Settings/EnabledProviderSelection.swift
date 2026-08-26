import Foundation

/// Welche Provider-ID die Sync-UI anzeigen soll, wenn die Aktivierungsliste sich ändert.
public enum EnabledProviderSelection: Sendable {
    /// Aktuelle Auswahl, sofern noch aktiv; sonst den ersten aktiven Provider.
    public static func resolved(
        selected: ProviderID,
        enabled: [ProviderID]
    ) -> ProviderID? {
        if enabled.contains(selected) {
            return selected
        }
        return enabled.first
    }
}
