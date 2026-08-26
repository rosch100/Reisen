import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func status(bookingStatus: String?, productStatus: String?) -> BookingStatus {
        if OpodoTripCancellationGraphQLParser.status(
            bookingStatus: bookingStatus,
            productStatus: productStatus
        ) == .cancelled {
            return .cancelled
        }
        let combined = [bookingStatus, productStatus]
            .compactMap { $0?.uppercased() }
        if combined.contains("CONFIRMED") || combined.contains("CONTRACT") {
            return .confirmed
        }
        return .unknown
    }
}
