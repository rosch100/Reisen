import Foundation
import ReisenDomain

extension OpodoTripCancellationGraphQLParser {
    func hotelPolicyDeadlines(from hotel: OpodoCancellationAccommodationDTO) -> [CancellationDeadline] {
        let policyStrings = [
            hotel.roomsGroupCancelPolicy,
            hotel.bookingCancelPolicy,
            hotel.accommodationCancelPolicy
        ].compactMap { $0 }.filter { !$0.isEmpty }

        guard !policyStrings.isEmpty else { return [] }
        let html = policyStrings.joined(separator: "\n")
        let parsedFromPolicyStrings = OpodoCancellationDeadlineParser().parseDeadlines(from: html)

        return parsedFromPolicyStrings.filter {
            ($0.policyText ?? "").localizedCaseInsensitiveContains("Stornierungsrichtlinie")
                || ($0.policyText ?? "").range(
                    of: #"\d{1,2}\.?\s*[A-Za-zÄÖÜäöü]+\s+\d{4}"#,
                    options: .regularExpression
                ) != nil
        }
    }

    func hotelOptionDeadlines(from hotel: OpodoCancellationAccommodationDTO) -> [CancellationDeadline] {
        let optionGroups = [
            hotel.cancellationInformation?.cancellationOptions,
            hotel.cancellationPolicies?.cancellationOptions
        ]
        var deadlines: [CancellationDeadline] = []
        for options in optionGroups {
            deadlines.append(contentsOf: deadlinesFromCancellationOptions(options, policyLabel: nil))
        }
        return deadlines
    }
}
