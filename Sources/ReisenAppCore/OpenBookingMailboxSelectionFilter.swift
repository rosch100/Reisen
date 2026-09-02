import Foundation

public enum OpenBookingMailboxSelectionFilter {
    public static func filter(
        selected: Set<UUID>,
        availableInDestination: Set<UUID>,
        fallbackFirst: UUID?
    ) -> Set<UUID> {
        let intersection = selected.intersection(availableInDestination)
        if !intersection.isEmpty {
            return intersection
        }
        if let fallbackFirst, availableInDestination.contains(fallbackFirst) {
            return [fallbackFirst]
        }
        if let first = availableInDestination.min(by: { $0.uuidString < $1.uuidString }) {
            return [first]
        }
        return []
    }
}

public enum TripMultiSelectionPrimary {
    public static func primaryID(in selected: Set<UUID>, anchor: UUID?) -> UUID? {
        if selected.count == 1 {
            return selected.first
        }
        guard !selected.isEmpty else { return nil }
        if let anchor, selected.contains(anchor) {
            return anchor
        }
        return selected.min(by: { $0.uuidString < $1.uuidString })
    }
}
