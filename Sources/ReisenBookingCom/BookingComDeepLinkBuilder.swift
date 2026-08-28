import Foundation
import ReisenDomain

/// Öffentliche Booking.com-Suche (Hotel + Flug) mit Gap-Prefill.
public struct BookingComDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.booking

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        bag.add(
            .hotel,
            url: hotelSearchURL(destination: gap.destinationHint, checkIn: gap.gapStart, checkOut: gap.gapEnd),
            missing: .missingDestinationHint
        )
        bag.add(
            .flight,
            url: flightSearchURL(from: gap.flightFromHint, to: gap.flightToHint, date: gap.gapStart),
            missing: .missingFromIATA
        )
        return bag.result
    }

    private func hotelSearchURL(destination: String?, checkIn: Date, checkOut: Date) -> URL? {
        guard let destination else { return nil }
        var components = URLComponents(string: "https://www.booking.com/searchresults.html")
        components?.queryItems = [
            URLQueryItem(name: "ss", value: destination),
            URLQueryItem(name: "checkin", value: GapDeepLinkText.posixDay(checkIn)),
            URLQueryItem(name: "checkout", value: GapDeepLinkText.posixDay(checkOut)),
            URLQueryItem(name: "group_adults", value: GapDeepLinkText.defaultLodgingAdults),
            URLQueryItem(name: "no_rooms", value: "1"),
        ]
        return components?.url
    }

    private func flightSearchURL(from: String?, to: String?, date: Date) -> URL? {
        guard let fromCode = GapDeepLinkText.firstIATA(in: from),
              let toCode = GapDeepLinkText.firstIATA(in: to) else { return nil }
        var components = URLComponents(string: "https://flights.booking.com/flights/\(fromCode).AIRPORT-\(toCode).AIRPORT/")
        components?.queryItems = [
            URLQueryItem(name: "type", value: "ONEWAY"),
            URLQueryItem(name: "adults", value: GapDeepLinkText.defaultFlightAdults),
            URLQueryItem(name: "cabinClass", value: "ECONOMY"),
            URLQueryItem(name: "from", value: fromCode),
            URLQueryItem(name: "to", value: toCode),
            URLQueryItem(name: "fromLocationName", value: fromCode),
            URLQueryItem(name: "toLocationName", value: toCode),
            URLQueryItem(name: "depart", value: GapDeepLinkText.posixDay(date)),
        ]
        return components?.url
    }
}
