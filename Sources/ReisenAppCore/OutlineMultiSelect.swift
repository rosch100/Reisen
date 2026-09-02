import Foundation

public enum OutlineMultiSelectClick: Equatable, Sendable {
    case replace
    case toggle
    case extendRange
}

public enum OutlineMultiSelect {
    public static func apply<ID: Hashable>(
        clicked: ID,
        current: Set<ID>,
        orderedVisible: [ID],
        anchor: ID?,
        click: OutlineMultiSelectClick
    ) -> (selected: Set<ID>, newAnchor: ID) {
        switch click {
        case .replace:
            return ([clicked], clicked)
        case .toggle:
            var next = current
            if next.contains(clicked) {
                next.remove(clicked)
            } else {
                next.insert(clicked)
            }
            if next.isEmpty {
                return ([clicked], clicked)
            }
            let newAnchor: ID
            if let anchor, next.contains(anchor) {
                newAnchor = anchor
            } else if next.contains(clicked) {
                newAnchor = clicked
            } else {
                newAnchor = next.min(by: { String(describing: $0) < String(describing: $1) }) ?? clicked
            }
            return (next, newAnchor)
        case .extendRange:
            guard let anchor,
                  let start = orderedVisible.firstIndex(of: anchor),
                  let end = orderedVisible.firstIndex(of: clicked)
            else {
                return ([clicked], clicked)
            }
            let lower = min(start, end)
            let upper = max(start, end)
            let selected = Set(orderedVisible[lower...upper])
            let newAnchor = selected.contains(anchor) ? anchor : clicked
            return (selected, newAnchor)
        }
    }

    public static func clickKind(shiftPressed: Bool, commandPressed: Bool) -> OutlineMultiSelectClick {
        if shiftPressed { return .extendRange }
        if commandPressed { return .toggle }
        return .replace
    }
}
