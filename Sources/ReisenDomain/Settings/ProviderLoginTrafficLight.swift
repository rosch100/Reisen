import Foundation

/// Sidebar-Ampel für Provider-Login-Status.
public enum ProviderLoginTrafficLight: Equatable, Sendable {
    case green
    case red
    case gray

    /// - Parameters:
    ///   - isEnabled: Provider-Checkbox aktiv
    ///   - isLoggedIn: `nil` = noch keine Session/Slot (bei aktivem Provider → rot)
    public static func resolve(isEnabled: Bool, isLoggedIn: Bool?) -> ProviderLoginTrafficLight {
        guard isEnabled else { return .gray }
        guard let isLoggedIn else { return .red }
        return isLoggedIn ? .green : .red
    }
}
