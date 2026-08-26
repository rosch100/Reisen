import Foundation
import ReisenDomain

extension OpodoActivityListParser {
    func draft(from match: NSTextCheckingResult, html: String) -> ProviderBookingDraft? {
        guard match.numberOfRanges == 4 else { return nil }

        guard let url = try? extractGroup(html: html, match: match, groupIndex: 1),
              let startRaw = try? extractGroup(html: html, match: match, groupIndex: 2),
              let endRaw = try? extractGroup(html: html, match: match, groupIndex: 3),
              let startAt = parseDate(startRaw),
              let endAt = parseDate(endRaw) else {
            return nil
        }

        return ProviderBookingDraft(
            provider: .opodo,
            bookingType: bookingType(from: url),
            title: nil,
            confirmationCode: nil,
            externalUrl: url,
            startAt: startAt,
            endAt: endAt,
            locationFrom: nil,
            locationTo: nil,
            status: .unknown,
            deadlines: [],
            rateDetails: nil
        )
    }
}
