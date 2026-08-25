import Foundation

/// SSOT: Gap-Art aus den angrenzenden Buchungstypen.
public enum GapKindClassifier {
    public static func classify(from: BookingType, to: BookingType) -> GapKind {
        if isOnSiteStay(from) || isOnSiteStay(to) { return .transport }
        guard isTransport(from), isTransport(to) else { return .both }
        return .lodging
    }

    private static func isOnSiteStay(_ type: BookingType) -> Bool {
        type == .hotel || type == .activity
    }

    private static func isTransport(_ type: BookingType) -> Bool {
        type == .flight || type == .ferry
    }
}
