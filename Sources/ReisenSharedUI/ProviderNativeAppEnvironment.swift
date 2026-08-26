import SwiftUI
import ReisenDomain

/// Plattformübergreifende Erkennung installierter Provider-Apps (iOS setzt den Wert).
public struct ProviderNativeAppPresenceReader: Sendable {
    public var isInstalled: @Sendable (ProviderID) -> Bool

    public init(isInstalled: @escaping @Sendable (ProviderID) -> Bool = { _ in false }) {
        self.isInstalled = isInstalled
    }
}

private struct ProviderNativeAppPresenceKey: EnvironmentKey {
    static let defaultValue = ProviderNativeAppPresenceReader()
}

public extension EnvironmentValues {
    var providerNativeAppPresence: ProviderNativeAppPresenceReader {
        get { self[ProviderNativeAppPresenceKey.self] }
        set { self[ProviderNativeAppPresenceKey.self] = newValue }
    }
}
