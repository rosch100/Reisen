import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func hotelDeadlinesFallback(from hotel: OpodoCancellationAccommodationDTO) -> [CancellationDeadline] {
        let policyLines = hotelPolicyDeadlines(from: hotel)
        if !policyLines.isEmpty {
            return policyLines
        }

        var deadlines: [CancellationDeadline] = []
        if let iso = hotel.cancellationDate, let parsed = parseISODate(iso) {
            deadlines.append(
                CancellationDeadline(
                    deadlineAt: parsed.date,
                    policyText: "Opodo cancellationDate",
                    isStrict: true,
                    isFreeCancellation: true,
                    hotelOffsetSeconds: parsed.offsetSeconds
                )
            )
        }

        deadlines.append(contentsOf: hotelOptionDeadlines(from: hotel))
        return deadlines
    }
}
