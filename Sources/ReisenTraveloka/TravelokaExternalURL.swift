import Foundation

enum TravelokaExternalURL {
    struct DetailIds: Equatable {
        var bookingId: String
        var itineraryId: String
        var productType: String?
    }

    static func detailIds(from externalUrl: String) throws -> DetailIds {
        guard let components = URLComponents(string: externalUrl) else {
            throw TravelokaProviderError.invalidBookingURL
        }
        let pathParts = components.path.split(separator: "/").map(String.init)
        guard let detailsIdx = pathParts.firstIndex(of: "details"),
              detailsIdx + 1 < pathParts.count
        else {
            throw TravelokaProviderError.invalidBookingURL
        }
        let bookingId = pathParts[detailsIdx + 1]
        let itineraryId = components.queryItems?.first(where: { $0.name == "id" })?.value
        let productType = components.queryItems?.first(where: { $0.name == "type" })?.value
        guard let itineraryId, !bookingId.isEmpty, !itineraryId.isEmpty else {
            throw TravelokaProviderError.missingBookingIdentifiers
        }
        return DetailIds(bookingId: bookingId, itineraryId: itineraryId, productType: productType)
    }

    static func ids(from externalUrl: String) throws -> (bookingId: String, itineraryId: String) {
        let detail = try detailIds(from: externalUrl)
        return (detail.bookingId, detail.itineraryId)
    }
}
