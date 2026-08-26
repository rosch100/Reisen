import SwiftUI
import ReisenDomain

public extension ProviderLoginTrafficLight {
    var color: Color {
        switch self {
        case .green: return .green
        case .red: return .red
        case .gray: return .secondary
        }
    }
}
