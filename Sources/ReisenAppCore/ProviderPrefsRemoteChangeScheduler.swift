import Foundation

/// Coalesces bursty `.NSPersistentStoreRemoteChange` handlers onto one MainActor turn.
@MainActor
public enum ProviderPrefsRemoteChangeScheduler {
    private static var pending: Task<Void, Never>?

    public static func schedule(_ work: @escaping @MainActor () -> Void) {
        pending?.cancel()
        pending = Task { @MainActor in
            await Task.yield()
            guard !Task.isCancelled else { return }
            work()
        }
    }
}
