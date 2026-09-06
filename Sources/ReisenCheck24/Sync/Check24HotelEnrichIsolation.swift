import Foundation
import ReisenProviders

enum Check24HotelEnrichIsolation {
    static func shouldRethrow(_ error: Error) -> Bool {
        if error is CancellationError { return true }
        if Task.isCancelled { return true }
        if NavigationSettleTimeout.isTimeout(error) { return false }
        return true
    }
}
