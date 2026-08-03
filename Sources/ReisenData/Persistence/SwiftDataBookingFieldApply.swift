import Foundation
import SwiftData
import ReisenDomain

/// Scalar field copy from domain booking onto SwiftData model (no child relations).
enum SwiftDataBookingFieldApply {
    static func applyScalars(_ booking: Booking, to model: SDBooking) {
        applyIdentity(booking, to: model)
        applyTimes(booking, to: model)
        applyLocations(booking, to: model)
        applyMeta(booking, to: model)
    }
}
