import Foundation

public enum BaggageAllowanceLabels {
    public static func label(for type: BaggageType) -> String? {
        switch type {
        case .checkedBag: return "Aufgabe"
        case .cabinBag: return "Hand"
        case .personalItem: return "Personal"
        case .unknown: return nil
        }
    }
}
