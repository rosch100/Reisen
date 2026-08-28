import Foundation
import ReisenDomain
import ReisenProviders

public struct Check24DeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.check24

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        bag.add(.hotel, make: {
            try makeHotelSearchURL(
                destinationHint: gap.destinationHint,
                checkIn: gap.gapStart,
                checkOut: gap.gapEnd
            )
        }, fallback: .destinationIdNotDerivable)
        bag.add(.flight, make: {
            try makeFlightSearchURL(
                fromHint: gap.flightFromHint,
                toHint: gap.flightToHint,
                date: gap.gapStart
            )
        }, fallback: .missingFromIATA)
        bag.add(.carRental, make: {
            try makeCarRentalSearchURL(for: gap)
        }, fallback: .missingDestinationHint)
        return bag.result
    }
}
