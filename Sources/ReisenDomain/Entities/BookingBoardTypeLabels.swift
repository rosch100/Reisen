import Foundation

public enum BookingBoardTypeLabels {
    public static func displayLabel(for type: BookingBoardType) -> String {
        switch type {
        case .roomOnly: return "Nur Zimmer"
        case .breakfastIncluded: return "Frühstück"
        case .halfBoard: return "Halbpension"
        case .fullBoard: return "Vollpension"
        case .unknown: return "Unbekannt"
        }
    }
}
