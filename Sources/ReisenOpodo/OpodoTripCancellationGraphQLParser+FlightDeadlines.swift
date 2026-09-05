import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func flightDeadlinesIfApplicable(
        trip: OpodoCancellationTripDTO,
        isHotelTrip: Bool
    ) -> [CancellationDeadline] {
        guard !isHotelTrip, let itinerary = trip.itinerary else { return [] }

        var deadlines: [CancellationDeadline] = []

        if let iso = itinerary.freeCancellation, let parsed = parseISODate(iso) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: parsed.date,
                    policyText: "Opodo freeCancellation",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: parsed.offsetSeconds
                )
            )
        }

        if let limit = itinerary.freeCancellationLimit?.limitTime,
           let date = dateFromEpochMillis(limit) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: date,
                    policyText: "Opodo freeCancellationLimit",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: nil
                )
            )
        }

        return deadlines
    }
}
