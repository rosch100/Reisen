import Foundation

/// SSOT: Gap-Art aus den angrenzenden Buchungstypen.
public enum GapKindClassifier {
    public static func classify(from: BookingType, to: BookingType) -> GapKind {
        if isOnSiteStay(from) || isOnSiteStay(to) { return .transport }
        guard from.isTransport, to.isTransport else { return .both }
        return .lodging
    }

    private static func isOnSiteStay(_ type: BookingType) -> Bool {
        type == .hotel || type == .activity
    }
}
