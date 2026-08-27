import Foundation

public extension ProviderLoginTrafficLight {
    var displayLabel: String {
        L10n.providerLoginStatusDisplay(self)
    }
}
