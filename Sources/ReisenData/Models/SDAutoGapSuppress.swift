import Foundation
import SwiftData

/// Persistierte Suppress-Keys für gelöschte Auto-Gap-Buchungen (pro Trip).
@Model
public final class SDAutoGapSuppress {
    public var id: UUID = UUID()
    public var tripID: UUID = UUID()
    public var identityKey: String = ""

    public init(
        id: UUID = UUID(),
        tripID: UUID,
        identityKey: String
    ) {
        self.id = id
        self.tripID = tripID
        self.identityKey = identityKey
    }
}
