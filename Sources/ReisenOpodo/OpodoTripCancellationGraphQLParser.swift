import Foundation
import ReisenDomain

/// Parst Stornofristen / Status aus `getTripByToken` JSON.
public struct OpodoTripCancellationGraphQLParser: Sendable {
    public init() {}

    public func parseDeadlines(from json: String) throws -> [CancellationDeadline] {
        try parse(from: json).deadlines
    }

    public func parse(from json: String) throws -> OpodoTripCancellationParseResult {
        let trip = try decodeTrip(from: json)
        guard let trip else {
            return OpodoTripCancellationParseResult(deadlines: [], status: nil)
        }

        let status = Self.status(
            bookingStatus: trip.accommodationBooking?.bookingStatus ?? trip.bookingStatus,
            productStatus: trip.bookingProductStatus,
            cancellableStatus: trip.accommodationProductBooking?.cancellationPolicies?.cancellableStatus
                ?? trip.accommodationBooking?.cancellationPolicies?.cancellableStatus
                ?? trip.accommodationBooking?.cancellationInformation?.cancellableStatus
        )

        let isHotelTrip = trip.accommodationBooking != nil || trip.accommodationProductBooking != nil
        var deadlines: [CancellationDeadline] = []
        deadlines.append(contentsOf: flightDeadlinesIfApplicable(trip: trip, isHotelTrip: isHotelTrip))
        deadlines.append(contentsOf: hotelProductOrFallbackDeadlines(from: trip))

        let deduped = dedupeDeadlines(deadlines)
        return OpodoTripCancellationParseResult(
            deadlines: deduped.sorted { $0.deadlineAt < $1.deadlineAt },
            status: status
        )
    }
}
