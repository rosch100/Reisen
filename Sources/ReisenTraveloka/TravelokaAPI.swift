import Foundation
import ReisenProviders

enum TravelokaAPI {
    static let origin = TravelokaWebConstants.origin
    static let routePrefix = TravelokaWebConstants.routePrefix

    static var loginURL: URL {
        let myBooking = "/\(routePrefix)/user/mybooking"
        return URL(string: "\(origin)/\(routePrefix)/user/signin?referrer=\(myBooking)")!
    }

    static func myBookingURL(routePrefix: String = TravelokaWebConstants.routePrefix) -> URL {
        routeURL(routePrefix, "user/mybooking")
    }

    static var itinerariesFetchURL: URL {
        URL(string: "\(origin)/api/v2/tripitinerary/itineraries/v2/fetch")!
    }

    static var itinerariesSingleURL: URL {
        URL(string: "\(origin)/api/v2/tripitinerary/itineraries/v2/single")!
    }

    static func detailURL(
        bookingId: String,
        itineraryId: String,
        productType: String,
        routePrefix: String = TravelokaWebConstants.routePrefix
    ) -> URL {
        routeURL(routePrefix, "item/details/\(bookingId)?type=\(productType)&id=\(itineraryId)")
    }

    static func refundPresubmissionURL(
        productType: String,
        bookingId: String,
        itineraryId: String,
        routePrefix: String = TravelokaWebConstants.routePrefix
    ) -> URL {
        routeURL(routePrefix, "refund/presubmission/\(productType)/\(bookingId)/\(itineraryId)")
    }

    static func tripItineraryHeaders(
        referer: String,
        context: TravelokaSessionContext
    ) -> [String: String] {
        context.applying(to: [
            "Accept": "application/json",
            "Content-Type": "application/json",
            "x-domain": "tripItinerary",
            "x-client-interface": TravelokaWebConstants.clientInterface,
            "Referer": referer,
        ])
    }

    static let catalogItineraryStatuses = ["UPCOMING"]

    static func catalogFetchBody(
        itineraryTypes: [String],
        itineraryStatus: String,
        context: TravelokaSessionContext
    ) throws -> Data {
        try encodePayload(
            context.withSentinel(in: [
                "fields": [] as [String],
                "data": [
                    "itineraryTypes": itineraryTypes,
                    "itineraryStatus": itineraryStatus,
                    "itineraryRequestOptions": ["ISSUED_ONLY"],
                    "featureConfig": [
                        "featureTypes": ["CUSTOMIZED_SECTION"],
                    ],
                ] as [String: Any],
                "clientInterface": TravelokaWebConstants.clientInterface,
            ])
        )
    }

    static func singleBody(
        bookingId: String,
        itineraryId: String,
        context: TravelokaSessionContext
    ) throws -> Data {
        try encodePayload(
            context.withSentinel(in: [
                "fields": [] as [String],
                "data": [
                    "bookingId": bookingId,
                    "itineraryId": itineraryId,
                    "featureConfig": [
                        "featureTypes": ["BOOKING_NAVIGATION"],
                    ],
                ],
                "clientInterface": TravelokaWebConstants.clientInterface,
            ])
        )
    }

    /// Product types requested for catalog (SSOT aligned with Traveloka mybooking cards).
    static let catalogItineraryTypes = [
        "FLIGHT",
        "HOTEL",
        "EXPERIENCE",
        "VEHICLE_RENTAL",
        "SHUTTLE_AIRPORT_TRANSPORT",
        "FLIGHT_ANCILLARY",
        "INSURANCE",
    ]

    private static func routeURL(_ routePrefix: String, _ path: String) -> URL {
        URL(string: "\(origin)/\(routePrefix)/\(path)")!
    }

    private static func encodePayload(_ payload: [String: Any]) throws -> Data {
        do {
            return try TravelokaJSONPayload.encode(payload)
        } catch {
            throw TravelokaProviderError.requestBodyEncodingFailed
        }
    }
}
