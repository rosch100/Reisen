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

        let bookingType = bookingType(from: url)
        let times = TemporalFact.pair(bookingType: bookingType, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: bookingType,
                start: times.start,
                end: times.end,
                externalUrl: url,
                statusRaw: nil
            )
        )
    }
}
