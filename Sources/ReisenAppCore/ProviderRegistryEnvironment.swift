import SwiftUI
import ReisenProviders

/// Optional environment value. Must not trap on read: SwiftUI resolves WritableKeyPaths
/// during environment propagation and will call the getter before the App injects a value.
private struct ProviderRegistryKey: EnvironmentKey {
    static let defaultValue: ProviderRegistry? = nil
}

extension EnvironmentValues {
    public var providerRegistry: ProviderRegistry? {
        get { self[ProviderRegistryKey.self] }
        set { self[ProviderRegistryKey.self] = newValue }
    }
}

