import SwiftUI

/// Optional environment value. Must not trap on read: SwiftUI resolves WritableKeyPaths
/// during environment propagation and will call the getter before the App injects a value.
private struct SyncStoreKey: EnvironmentKey {
    static let defaultValue: SyncStore? = nil
}

extension EnvironmentValues {
    public var syncStore: SyncStore? {
        get { self[SyncStoreKey.self] }
        set { self[SyncStoreKey.self] = newValue }
    }
}

