import Foundation

public enum BookingStatus: String, Codable, CaseIterable, Identifiable, Sendable {
    case confirmed
    case cancelled
    case unknown

    public var id: String { rawValue }

    /// UI-Label (Details, Editor, Listen).
    public var displayLabel: String {
        L10n.bookingStatusDisplay(self)
    }
}
