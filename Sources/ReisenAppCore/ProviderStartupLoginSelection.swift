import ReisenDomain

/// Reine Auswahl-Logik für Startup-Login-Queue.
///
/// Speichert Provider-IDs aus einem Snapshot — nie einen Index in die live
/// berechnete Enabled-Liste (Regression: Array-OOB nach `await` Probe).
public enum ProviderStartupLoginSelection: Sendable {
    public static func firstNeedingLogin(
        providersInOrder: [ProviderID],
        isSessionReady: (ProviderID) -> Bool
    ) -> ProviderID? {
        providersInOrder.first { !isSessionReady($0) }
    }

    public static func remainingToProbe(
        providersInOrder: [ProviderID],
        after selected: ProviderID,
        stillEnabled: Set<ProviderID>
    ) -> [ProviderID] {
        guard let selectedIndex = providersInOrder.firstIndex(of: selected) else {
            return providersInOrder.filter { stillEnabled.contains($0) && $0 != selected }
        }
        return providersInOrder[(selectedIndex + 1)...]
            .filter { stillEnabled.contains($0) }
    }
}
