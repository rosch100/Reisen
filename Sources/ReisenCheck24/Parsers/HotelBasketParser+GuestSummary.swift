import Foundation

extension HotelBasketParser {
    static func guestSummary(from room: HotelBasketDetailsDTO.RoomDTO) -> String? {
        // Check24 liefert bei manchen Baskets Platzhalter `"-"` anstatt echter Namen.
        // Kanonisch darstellen: erster bekannter Name + „und N weitere Gäste“.
        let guests = room.guests ?? []
        guard !guests.isEmpty else { return nil }

        let knownNames: [String] = guests.compactMap { guest in
            guestDisplayName(first: guest.firstName, last: guest.lastName)
        }

        return formatGuestSummary(
            knownNames: knownNames,
            placeholderCount: guests.count - knownNames.count
        )
    }
}
