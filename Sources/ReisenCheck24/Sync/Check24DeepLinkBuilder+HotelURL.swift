import Foundation
import ReisenDomain
import ReisenProviders

extension Check24DeepLinkBuilder {
    func makeHotelSearchURL(destinationHint: String?, checkIn: Date, checkOut: Date) throws -> URL {
        guard let destinationHint else {
            throw DeepLinkIssue.missingDestinationHint
        }
        let (destinationName, destinationId) = try hotelDestinationParts(from: destinationHint)
        let occupancyPath = "%5BA%7CA%5D"
        let urlString =
            "https://\(Check24KundenbereichHost.hotel)/search/\(destinationName)-\(destinationId)/\(GapDeepLinkText.posixDay(checkIn))/\(GapDeepLinkText.posixDay(checkOut))/\(occupancyPath)/"
        guard let url = URL(string: urlString) else { throw DeepLinkIssue.destinationIdNotDerivable }
        return url
    }
}
