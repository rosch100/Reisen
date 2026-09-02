import Foundation

public enum MenuEffectiveSelection {
    public static func resolve<ID: Hashable>(clicked: ID, selected: Set<ID>) -> Set<ID> {
        if selected.contains(clicked) {
            return selected
        }
        return [clicked]
    }
}
