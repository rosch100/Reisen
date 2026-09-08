import ReisenDomain

/// SF Symbol für Gap-Zeilen (HIG-SSOT, UI-Schicht) — macOS und iOS identisch.
public extension GapKind {
    var systemImageName: String {
        switch self {
        case .lodging:
            return "bed.double.fill"
        case .transport, .both:
            return "arrow.left.arrow.right"
        }
    }
}
