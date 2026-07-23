import SwiftUI

private struct ProviderSessionHubKey: EnvironmentKey {
    static let defaultValue: ProviderSessionHub? = nil
}

extension EnvironmentValues {
    public var providerSessionHub: ProviderSessionHub? {
        get { self[ProviderSessionHubKey.self] }
        set { self[ProviderSessionHubKey.self] = newValue }
    }
}

