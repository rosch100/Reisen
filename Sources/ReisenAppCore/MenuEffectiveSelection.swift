import Foundation

public enum MenuEffectiveSelection {
    public static func resolve<ID: Hashable>(clicked: ID, selected: Set<ID>) -> Set<ID> {
        if selected.contains(clicked) {
            return selected
        }
        return [clicked]
    }

    /// Bound-Merge für `List.contextMenu(forSelectionType:)` gegen Selection-SSOT.
    /// Singleton-Menü → wie `resolve(clicked:selected:)`; Menü ⊆ Bound → volles Bound.
    public static func resolve<ID: Hashable>(menu: Set<ID>, bound: Set<ID>) -> Set<ID> {
        guard !menu.isEmpty else { return [] }
        if menu.count == 1, let clicked = menu.first {
            return resolve(clicked: clicked, selected: bound)
        }
        if menu.isSubset(of: bound) {
            return bound
        }
        return menu
    }
}
