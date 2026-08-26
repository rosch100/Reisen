import Foundation
import ReisenDomain

extension ActivityListParser {
    /// Nur Reiseprodukte, die nicht storniert/beendet sind und deren Start in der Zukunft liegt.
    func parseOneActivityIfRelevant(_ activity: [String: Any], now: Date = Date()) -> ParsedBooking? {
        let productKey = productKey(from: activity)
        guard Self.travelProductKeys.contains(productKey) else { return nil }

        let bookingType = mapBookingType(productKey)

        let startRaw = activity["startDate"] as? String
            ?? activity["start_date"] as? String
            ?? (activity["product_specific_data"] as? [String: Any])?["hotel_date_arrival"] as? String
            ?? (activity["productSpecificData"] as? [String: Any])?["hotel_date_arrival"] as? String
        let endRaw = activity["endDate"] as? String
            ?? activity["end_date"] as? String
            ?? (activity["product_specific_data"] as? [String: Any])?["hotel_date_departure"] as? String
            ?? (activity["productSpecificData"] as? [String: Any])?["hotel_date_departure"] as? String

        let startAt: Date? = {
            guard bookingType == .hotel else { return parseFlexibleDate(startRaw) }
            return parseHotelDay(startRaw)
        }()
        let endAt: Date? = {
            guard bookingType == .hotel else { return parseFlexibleDate(endRaw) }
            return parseHotelDay(endRaw)
        }()

        guard let startAt, let endAt else { return nil }

        let statusKey = activityStatusKey(from: activity)
        guard isFutureRelevantBooking(statusKey: statusKey, startAt: startAt, now: now) else {
            return nil
        }

        let externalUrl = activityDetailURL(from: activity)
        let confirmationCode =
            (activity["foreignId"] as? String)
            ?? (activity["foreign_id"] as? String)
            ?? ((activity["product_specific_data"] as? [String: Any])?["booking_number"] as? String)

        let catalogPrice = activityPayment(from: activity)
        let roomInfo = activityRoomInfo(from: activity)

        let details = detailsFromCatalogPrice(
            catalogPrice: catalogPrice,
            roomInfo: roomInfo,
            bookingType: bookingType
        )

        return ParsedBooking(
            type: bookingType,
            title: activityTitle(from: activity),
            confirmationCode: confirmationCode,
            externalUrl: externalUrl,
            startAt: startAt,
            endAt: endAt,
            locationFrom: nil,
            locationTo: activityLocation(from: activity),
            locationFromAddress: nil,
            locationToAddress: activityAddress(from: activity),
            status: mapBookingStatus(statusKey),
            details: details,
            catalogPriceAmount: catalogPrice.amount,
            catalogPriceCurrency: catalogPrice.currency,
            catalogRoomCount: roomInfo.count,
            catalogRoomCategory: roomInfo.category
        )
    }
}
