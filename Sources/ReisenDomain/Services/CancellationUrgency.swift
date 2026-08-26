import Foundation

public enum CancellationUrgency: Equatable, Sendable {
    case fix
    case critical
    case warning
    case ok

    public var label: String {
        switch self {
        case .fix: return "Fix"
        case .critical: return "Rot"
        case .warning: return "Orange"
        case .ok: return ""
        }
    }
}
