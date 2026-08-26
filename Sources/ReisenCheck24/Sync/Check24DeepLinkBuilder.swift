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
        do {
            let hotelURL = try makeHotelSearchURL(
                destinationHint: destinationHint,
                checkIn: gap.gapStart,
                checkOut: gap.gapEnd
            )
            links.append(DeepLinkSuggestion(title: "Hotel suchen (Check24)", url: hotelURL))
        } catch let issue as DeepLinkIssue {
            issues.append(issue)
        } catch {
            issues.append(.destinationIdNotDerivable)
        }

        do {
            // Zwischen-Transport: Abflug = letzter Ankunftsort, Ziel = Ort der nächsten Buchung.
            let flightURL = try makeFlightSearchURL(
                fromHint: gap.fromLocationTo ?? gap.fromLocationFrom,
                toHint: gap.toLocationFrom ?? gap.toLocationTo,
                date: gap.gapStart
            )
            links.append(DeepLinkSuggestion(title: "Flug suchen (Check24)", url: flightURL))
        } catch let issue as DeepLinkIssue {
            issues.append(issue)
        } catch {
            issues.append(.missingFromIATA)
        }

        return (links, issues)
    }
}
