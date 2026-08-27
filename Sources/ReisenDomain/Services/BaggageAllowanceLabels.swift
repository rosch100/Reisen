import Foundation

public enum BaggageAllowanceLabels {
    public static func label(for type: BaggageType) -> String? {
        switch type {
        case .checkedBag, .cabinBag, .personalItem:
            return L10n.baggageTypeShortDisplay(type)
        case .unknown:
            return nil
        }
    }
}
