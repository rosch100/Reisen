import ReisenDomain

/// Lokale Multi-Select-Semantik für den First-Launch-Dialog „Buchungsportale wählen“.
public enum ProviderSetupSelection: Sendable {
    /// `true`, wenn `allIDs` nicht leer ist und jedes Element in `current` liegt.
    public static func areAllSelected(
        current: Set<ProviderID>,
        allIDs: [ProviderID]
    ) -> Bool {
        !allIDs.isEmpty && allIDs.allSatisfy { current.contains($0) }
    }

    /// Alle auswählen, wenn nicht vollständig gewählt; sonst Auswahl leeren.
    public static func toggleAll(
        current: Set<ProviderID>,
        allIDs: [ProviderID]
    ) -> Set<ProviderID> {
        if areAllSelected(current: current, allIDs: allIDs) {
            return []
        }
        return Set(allIDs)
    }
}
