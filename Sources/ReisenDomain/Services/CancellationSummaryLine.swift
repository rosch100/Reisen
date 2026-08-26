import Foundation

public enum CancellationSummaryLineKind: Equatable, Sendable {
    case fix
    case free
    case paid
}

public struct CancellationSummaryLine: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let kind: CancellationSummaryLineKind
    public let text: String
    public let systemImageName: String

    /// Nur für `.free`. UI kann daraus Farben ableiten.
    public let urgency: CancellationUrgency?

    public init(
        id: UUID,
        kind: CancellationSummaryLineKind,
        text: String,
        systemImageName: String,
        urgency: CancellationUrgency? = nil
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.systemImageName = systemImageName
        self.urgency = urgency
    }

    public static let fixID: UUID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
}
