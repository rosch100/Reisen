import Foundation
import ReisenDomain

extension Notification.Name {
    /// Single-provider sync after portal cancel completion (object: `ProviderID`).
    public static let reisenSyncProvider = Notification.Name("reisenSyncProvider")
}
