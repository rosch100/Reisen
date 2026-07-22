import SwiftUI

private struct ProviderSessionHubKey: EnvironmentKey {
    static let defaultValue: ProviderSessionHub? = nil
}

extension EnvironmentValues {
    var providerSessionHub: ProviderSessionHub? {
        get { self[ProviderSessionHubKey.self] }
        set { self[ProviderSessionHubKey.self] = newValue }
    }
}
