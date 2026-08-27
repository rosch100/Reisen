import Foundation

public enum BookingBoardTypeLabels {
    public static func displayLabel(for type: BookingBoardType) -> String {
        L10n.boardTypeDisplay(type)
    }
}
