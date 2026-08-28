import Foundation
import ReisenDomain
import ReisenProviders

public struct Check24DeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.check24

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var issues: [DeepLinkIssue] = []
        var links: [DeepLinkSuggestion] = []

        let destinationHint = gap.fromLocationTo ?? gap.toLocationFrom ?? gap.toLocationTo
        appendSuggestion(
            title: "Hotel suchen (Check24)",
            into: &links,
            issues: &issues,
            fallbackIssue: .destinationIdNotDerivable
        ) {
            try makeHotelSearchURL(
                destinationHint: destinationHint,
                checkIn: gap.gapStart,
                checkOut: gap.gapEnd
            )
        }

        appendSuggestion(
            title: "Flug suchen (Check24)",
            into: &links,
            issues: &issues,
            fallbackIssue: .missingFromIATA
        ) {
            // Zwischen-Transport: Abflug = letzter Ankunftsort, Ziel = Ort der nächsten Buchung.
            try makeFlightSearchURL(
                fromHint: gap.fromLocationTo ?? gap.fromLocationFrom,
                toHint: gap.toLocationFrom ?? gap.toLocationTo,
                date: gap.gapStart
            )
        }

        appendSuggestion(
            title: "Mietwagen suchen (Check24)",
            into: &links,
            issues: &issues,
            fallbackIssue: .missingDestinationHint
        ) {
            try makeCarRentalSearchURL(for: gap)
        }

        return (links, issues)
    }

    private func appendSuggestion(
        title: String,
        into links: inout [DeepLinkSuggestion],
        issues: inout [DeepLinkIssue],
        fallbackIssue: DeepLinkIssue,
        makeURL: () throws -> URL
    ) {
        do {
            let url = try makeURL()
            links.append(DeepLinkSuggestion(title: title, url: url))
        } catch let issue as DeepLinkIssue {
            issues.append(issue)
        } catch {
            issues.append(fallbackIssue)
        }
    }
}
