import Foundation
import ReisenDomain

/// Öffentliche Airbnb-Homes-Suche mit Gap-Prefill (Check-in/out + Ort).
public struct AirbnbDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.airbnb

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        guard let destination = gap.destinationHint else {
            bag.add(.hotel, url: nil, missing: .missingDestinationHint)
            return bag.result
        }
        bag.add(.hotel, url: homesURL(destination: destination, gap: gap), missing: .destinationIdNotDerivable)
        return bag.result
    }

    private func homesURL(destination: String, gap: GapContext) -> URL? {
        let encoded = destination
            .replacingOccurrences(of: "/", with: " ")
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? destination
        var components = URLComponents(string: "https://www.airbnb.de/s/\(encoded)/homes")
        components?.queryItems = [
            URLQueryItem(name: "checkin", value: GapDeepLinkText.posixDay(gap.gapStart)),
            URLQueryItem(name: "checkout", value: GapDeepLinkText.posixDay(gap.gapEnd)),
            URLQueryItem(name: "adults", value: GapDeepLinkText.defaultLodgingAdults),
        ]
        return components?.url
    }
}
