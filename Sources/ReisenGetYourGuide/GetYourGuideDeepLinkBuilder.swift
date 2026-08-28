import Foundation
import ReisenDomain

/// Öffentliche GetYourGuide-Suche mit Ort + Datumsfenster.
public struct GetYourGuideDeepLinkBuilder: GapDeepLinkBuilding {
    public let providerID = ProviderID.getYourGuide

    public init() {}

    public func suggestions(for gap: GapContext) -> (links: [DeepLinkSuggestion], issues: [DeepLinkIssue]) {
        var bag = GapDeepLinkBag(providerID: providerID, kind: gap.kind)
        guard let destination = gap.destinationHint else {
            bag.add(.activity, url: nil, missing: .missingDestinationHint)
            return bag.result
        }
        bag.add(.activity, url: searchURL(destination: destination, gap: gap), missing: .destinationIdNotDerivable)
        return bag.result
    }

    private func searchURL(destination: String, gap: GapContext) -> URL? {
        var components = URLComponents(string: "\(GetYourGuideWebConstants.origin)/s/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: destination),
            URLQueryItem(name: "date_from", value: GapDeepLinkText.posixDay(gap.gapStart)),
            URLQueryItem(name: "date_to", value: GapDeepLinkText.posixDay(gap.gapEnd)),
        ]
        return components?.url
    }
}
