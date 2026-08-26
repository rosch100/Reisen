import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    /// Erkennt stornierte Trips in GraphQL-Statusfeldern bzw. Opodo-Detail-HTML.
    /// Wichtig: `CANCELLABLE` enthält „CANCEL“, ist aber kein Storno.
    public static func status(
        bookingStatus: String?,
        productStatus: String?,
        cancellableStatus: String? = nil
    ) -> BookingStatus? {
        let tokens = [bookingStatus, productStatus, cancellableStatus]
            .compactMap { $0?.uppercased() }
        if tokens.contains(where: isCancelledStatusToken) {
            return .cancelled
        }
        return nil
    }
}
