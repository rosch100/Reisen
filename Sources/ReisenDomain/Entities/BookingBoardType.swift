import Foundation

public enum BookingBoardType: String, Codable, CaseIterable, Identifiable, Sendable {
    case roomOnly
    case breakfastIncluded
    case halfBoard
    case fullBoard
    case unknown

    public var id: String { rawValue }

    /// UI-Label inkl. „Unbekannt“ (Editor/Picker).
    public var displayLabel: String {
        BookingBoardTypeLabels.displayLabel(for: self)
    }

    /// Detail-Anzeige: `nil` bei `.unknown`, sonst `displayLabel`.
    public var displayLabelIfKnown: String? {
        self == .unknown ? nil : displayLabel
    }
}
