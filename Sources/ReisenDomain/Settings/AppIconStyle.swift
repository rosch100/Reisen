import Foundation

/// Homescreen-App-Icon-Variante (iOS Alternate Icons).
public enum AppIconStyle: String, CaseIterable, Sendable, Codable {
    /// Primary Asset (`AppIcon` / dunkler Hintergrund).
    case standard = "standard"
    /// Alternate Asset (`AppIconLight` / heller Hintergrund).
    case light = "light"

    /// Argument für `UIApplication.setAlternateIconName` — `nil` = Primary.
    public var alternateIconName: String? {
        switch self {
        case .standard:
            return nil
        case .light:
            return "AppIconLight"
        }
    }

    public static func from(stored: String?) -> AppIconStyle {
        guard let stored, let style = AppIconStyle(rawValue: stored) else {
            return .standard
        }
        return style
    }
}
