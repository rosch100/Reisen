import Foundation
import SwiftData
import ReisenDomain

extension SwiftDataBookingRateDetailsUpsert {
    static func upsertRooms(
        _ rooms: [BookingRoomItem],
        on existing: SDBookingRateDetails,
        in context: ModelContext
    ) {
        var remainingRooms = existing.roomItems ?? []
        var keptRooms: [SDBookingRoomItem] = []
        for room in rooms {
            let item = takeOrCreateRoom(room, from: &remainingRooms, rateDetails: existing, in: context)
            applyRoom(room, to: item, rateDetails: existing)
            keptRooms.append(item)
        }
        SwiftDataBookingMatchHelpers.deleteAll(remainingRooms, in: context)
        existing.roomItems = keptRooms
    }

    static func takeOrCreateRoom(
        _ room: BookingRoomItem,
        from remaining: inout [SDBookingRoomItem],
        rateDetails: SDBookingRateDetails,
        in context: ModelContext
    ) -> SDBookingRoomItem {
        if let found = SwiftDataBookingMatchHelpers.takeMatching(
            from: &remaining,
            id: room.id,
            idOf: \.id,
            contentMatch: {
                SwiftDataBookingContentKeys.room(
                    confirmationCode: $0.confirmationCode,
                    sortIndex: $0.sortIndex,
                    category: $0.category
                ) == SwiftDataBookingContentKeys.room(
                    confirmationCode: room.confirmationCode,
                    sortIndex: room.sortIndex,
                    category: room.category
                )
            }
        ) {
            return found
        }
        let item = SDBookingRoomItem(id: room.id, rateDetails: rateDetails)
        context.insert(item)
        return item
    }

    static func applyRoom(_ room: BookingRoomItem, to item: SDBookingRoomItem, rateDetails: SDBookingRateDetails) {
        item.rateDetails = rateDetails
        item.category = room.category
        item.confirmationCode = room.confirmationCode
        item.priceAmount = room.priceAmount
        item.priceCurrency = room.priceCurrency
        item.guestSummary = room.guestSummary
        item.externalUrl = room.externalUrl
        item.sortIndex = room.sortIndex
    }
}
