import Foundation
import ReisenDomain

extension OpodoTripsGraphQLParser {
    func roomCategory(from rooms: [OpodoGraphQLBookingRoom]?) -> String? {
        guard let rooms else { return nil }
        var seen = Set<String>()
        var ordered: [String] = []
        for room in rooms {
            guard let name = nonEmpty(room.roomDescription) else { continue }
            if seen.insert(name).inserted {
                ordered.append(name)
            }
        }
        guard !ordered.isEmpty else { return nil }
        return ordered.joined(separator: ", ")
    }

    func roomItems(from rooms: [OpodoGraphQLBookingRoom]?) -> [BookingRoomItem] {
        guard let rooms else { return [] }
        return rooms.enumerated().compactMap { idx, room in
            guard let category = nonEmpty(room.roomDescription) else { return nil }
            return BookingRoomItem(
                category: category,
                sortIndex: idx
            )
        }
    }
}
