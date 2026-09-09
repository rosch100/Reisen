import Foundation

/// Parst `reisenLoginFields`-Script-Messages (Fokus für TabBar-Hide auf iOS).
public enum LoginFieldHintsMessage {
    /// `true`/`false` bei Fokus-Events; `nil` für andere Payload-Typen.
    public static func webLoginInputFocused(_ body: Any) -> Bool? {
        guard let dict = body as? [String: Any],
              let type = dict["type"] as? String else {
            return nil
        }
        switch type {
        case "inputFocused":
            return true
        case "inputBlurred":
            return false
        default:
            return nil
        }
    }
}
