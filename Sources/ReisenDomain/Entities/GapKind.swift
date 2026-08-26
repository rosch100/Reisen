import Foundation

public enum GapKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case lodging
    case transport
    case both

    public var id: String { rawValue }

    /// Default UI title when no override is stored.
    public var defaultDisplayTitle: String {
        switch self {
        case .lodging: return "Private Übernachtung"
        case .transport: return "Zwischen-Transport"
        case .both: return "Lücke"
        }
    }
}
