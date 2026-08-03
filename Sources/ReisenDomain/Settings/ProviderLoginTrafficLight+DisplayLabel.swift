import Foundation

public extension ProviderLoginTrafficLight {
    var displayLabel: String {
        switch self {
        case .green: return "Angemeldet"
        case .red: return "Anmeldung erforderlich"
        case .gray: return "Provider deaktiviert"
        }
    }
}
