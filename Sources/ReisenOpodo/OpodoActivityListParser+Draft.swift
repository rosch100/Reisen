import Foundation
import ReisenDomain

extension OpodoActivityListParser {
    func draft(from match: NSTextCheckingResult, html: String) throws -> ProviderBookingDraft? {
        guard let groups = try hrefDateGroups(from: match, html: html) else { return nil }
        guard let startAt = parseDate(groups.startRaw),
              let endAt = parseDate(groups.endRaw) else {
            return nil
        }

        guard let bookingType = bookingType(from: groups.url) else { return nil }
        let times = TemporalFact.pair(bookingType: bookingType, start: startAt, end: endAt)
        return DraftAssembler.draft(
            from: ProviderBookingFacts(
                provider: .opodo,
                bookingType: bookingType,
                start: times.start,
                end: times.end,
                externalUrl: groups.url,
                statusRaw: nil
            )
        )
    }
}
