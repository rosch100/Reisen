import Foundation
import ReisenDomain

public enum DomainMapper {
    public static func trip(from model: SDTrip) -> Trip {
        Trip(
            id: model.id,
            title: model.title,
            startDate: model.startDate,
            endDate: model.endDate,
            destination: model.destination,
            notes: model.notes,
            bookingIDs: (model.bookings ?? []).map(\.id)
        )
    }
}
