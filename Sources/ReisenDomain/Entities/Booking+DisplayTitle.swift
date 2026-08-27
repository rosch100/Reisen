import Foundation

extension Booking {
    /// Anzeigetitel für Reminder/Kalender und Side-Effects (SSOT).
    public var displayTitle: String {
        title ?? bookingType.defaultDisplayTitle
    }

    public func displayTitle(using lookup: [UUID: String]) -> String {
        lookup[id] ?? displayTitle
    }
}

extension Collection where Element == Booking {
    public var titleByID: [UUID: String] {
        Dictionary(uniqueKeysWithValues: map { ($0.id, $0.displayTitle) })
    }
}
