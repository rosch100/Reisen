import Foundation
import ReisenDomain

extension ActivityListParser {
    /// Nur Reiseprodukte, die nicht storniert/beendet sind und deren Start in der Zukunft liegt.
    func parseOneActivityIfRelevant(_ activity: [String: Any], now: Date = Date()) -> ParsedBooking? {
        let productKey = productKey(from: activity)
        guard Self.travelProductKeys.contains(productKey) else { return nil }

        let bookingType = mapBookingType(productKey)
        let psd = productSpecificData(from: activity)

        let startRaw = jsonString(activity, "startDate", "start_date")
            ?? jsonString(psd, "hotel_date_arrival")
        let endRaw = jsonString(activity, "endDate", "end_date")
            ?? jsonString(psd, "hotel_date_departure")

        let startAt = parseCatalogDate(startRaw, bookingType: bookingType)
        let endAt = parseCatalogDate(endRaw, bookingType: bookingType)

        guard let startAt, let endAt else { return nil }

        let statusKey = activityStatusKey(from: activity)
        guard isFutureRelevantBooking(statusKey: statusKey, startAt: startAt, now: now) else {
            return nil
        }

        let externalUrl = activityDetailURL(from: activity)
        let confirmationCode = jsonString(activity, "foreignId", "foreign_id")
            ?? jsonString(psd, "booking_number")

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
            statusRaw: statusKey,
            details: details,
            catalogPriceAmount: catalogPrice.amount,
            catalogPriceCurrency: catalogPrice.currency,
            catalogRoomCount: roomInfo.count,
            catalogRoomCategory: roomInfo.category
        )
    }

    func jsonString(_ dict: [String: Any], _ keys: String...) -> String? {
        keys.lazy.compactMap { NonEmpty.string(dict[$0] as? String) }.first
    }
}
