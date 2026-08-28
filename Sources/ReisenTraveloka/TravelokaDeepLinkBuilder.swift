import Foundation
import ReisenDomain
import ReisenProviders

public struct TravelokaDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.traveloka

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        let destination = gap.destinationHint
        bag.add(
            .hotel,
            url: hotelSearchURL(destination: destination, checkIn: gap.gapStart, checkOut: gap.gapEnd),
            missing: .missingDestinationHint
        )
        bag.add(
            .flight,
            url: flightSearchURL(from: gap.flightFromHint, to: gap.flightToHint, date: gap.gapStart),
            missing: .missingFromIATA
        )
        bag.add(
            .activity,
            url: activitiesSearchURL(destination: destination),
            missing: .missingDestinationHint
        )
        return bag.result
    }

    private func hotelSearchURL(destination: String?, checkIn: Date, checkOut: Date) -> URL? {
        guard let destination else { return nil }
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/hotel/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: destination),
            URLQueryItem(name: "checkin", value: GapDeepLinkText.posixDay(checkIn, format: GapDeepLinkText.travelokaDayFormat)),
            URLQueryItem(name: "checkout", value: GapDeepLinkText.posixDay(checkOut, format: GapDeepLinkText.travelokaDayFormat)),
        ]
        return components?.url
    }

    private func flightSearchURL(from: String?, to: String?, date: Date) -> URL? {
        guard let fromCode = GapDeepLinkText.firstIATA(in: from),
              let toCode = GapDeepLinkText.firstIATA(in: to) else { return nil }
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/flight/fullsearch")
        components?.queryItems = [
            URLQueryItem(name: "ap", value: "\(fromCode).\(toCode)"),
            URLQueryItem(name: "dt", value: GapDeepLinkText.posixDay(date, format: GapDeepLinkText.travelokaDayFormat)),
            URLQueryItem(name: "ps", value: "1.0.0"),
        ]
        return components?.url
    }

    private func activitiesSearchURL(destination: String?) -> URL? {
        guard let destination else { return nil }
        var components = URLComponents(string: "\(TravelokaAPI.origin)/\(TravelokaAPI.routePrefix)/activities")
        components?.queryItems = [URLQueryItem(name: "q", value: destination)]
        return components?.url
    }
}
