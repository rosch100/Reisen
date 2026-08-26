import SwiftUI

private struct ProviderEnableEpochKey: EnvironmentKey {
    static let defaultValue = 0
}

public extension EnvironmentValues {
    var providerEnableEpoch: Int {
        get { self[ProviderEnableEpochKey.self] }
        set { self[ProviderEnableEpochKey.self] = newValue }
    }
}
