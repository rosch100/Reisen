import Foundation

public enum GapKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case lodging
    case transport
    case both

    public var id: String { rawValue }

    /// Default UI title when no override is stored.
    public var defaultDisplayTitle: String {
        L10n.gapKindDisplay(self)
    }
}
