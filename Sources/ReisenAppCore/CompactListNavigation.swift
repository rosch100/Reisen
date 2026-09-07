import Foundation

/// Compact iOS list→detail: Selection steuert nur Split; Path-Push braucht `compactPush`.
public enum CompactListNavigation {
    /// `List(selection:)` nur im Split — auf Compact fängt Selection den Tip ab ohne Path-Append.
    public static func listUsesSelectionBinding(usesSplit: Bool) -> Bool {
        usesSplit
    }

    /// User-Tip auf Compact: Selection + einmaliger `compactPush` (gleicher Kanal wie Paste-Import).
    public static func applyUserSelect(
        id: UUID,
        selection: inout UUID?,
        compactPush: inout UUID?
    ) {
        selection = id
        compactPush = id
    }
}
