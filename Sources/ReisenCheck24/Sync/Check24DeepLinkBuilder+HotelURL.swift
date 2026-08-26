import Foundation
import ReisenDomain
import ReisenProviders

extension Check24DeepLinkBuilder {
    func makeHotelSearchURL(destinationHint: String?, checkIn: Date, checkOut: Date) throws -> URL {
        guard let destinationHint, !destinationHint.isEmpty else {
            throw DeepLinkIssue.missingDestinationHint
        }
        let (destinationName, destinationId) = try hotelDestinationParts(from: destinationHint)
        let df = Self.posixDayFormatter
        let occupancyPath = "%5BA%7CA%5D"
        let urlString =
            "https://hotel.check24.de/search/\(destinationName)-\(destinationId)/\(df.string(from: checkIn))/\(df.string(from: checkOut))/\(occupancyPath)/"
        guard let url = URL(string: urlString) else { throw DeepLinkIssue.destinationIdNotDerivable }
        return url
    }
}
