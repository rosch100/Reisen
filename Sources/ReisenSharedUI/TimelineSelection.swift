import Foundation

/// Primary-Selection aus einem Timeline-Selection-Set (HIG Multi-Select).
public enum TimelineSelection {
    /// Nur bei genau einem Element; sonst `nil` (ungeordnetes `Set`).
    public static func primaryID(in selectedIDs: Set<String>) -> String? {
        guard selectedIDs.count == 1 else { return nil }
        return selectedIDs.first
    }
}
