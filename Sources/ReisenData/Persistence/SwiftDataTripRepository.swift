import Foundation
import SwiftData
import ReisenDomain

@MainActor
public final class SwiftDataTripRepository: TripRepository {
    private let modelContext: ModelContext

    public init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    public func fetchAll() throws -> [Trip] {
        try modelContext.fetch(FetchDescriptor<SDTrip>()).map(DomainMapper.trip(from:))
    }

    public func fetch(id: UUID) throws -> Trip? {
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        return try modelContext.fetch(descriptor).first.map(DomainMapper.trip(from:))
    }

    public func upsert(_ trip: Trip) throws {
        let tripID = trip.id
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
        let model: SDTrip
        if let existing = try modelContext.fetch(descriptor).first {
            model = existing
        } else {
            model = SDTrip(
                id: tripID,
                title: trip.title,
                startDate: trip.startDate,
                endDate: trip.endDate
            )
            modelContext.insert(model)
        }
        model.title = trip.title
        model.startDate = trip.startDate
        model.endDate = trip.endDate
        model.destination = trip.destination
        model.notes = trip.notes
    }

    public func delete(id: UUID) throws {
        let descriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == id })
        guard let model = try modelContext.fetch(descriptor).first else {
            throw RepositoryError.notFound("Trip \(id)")
        }
        modelContext.delete(model)
    }

    public func assignBooking(bookingID: UUID, toTripID tripID: UUID?) throws {
        let bookingDescriptor = FetchDescriptor<SDBooking>(predicate: #Predicate { $0.id == bookingID })
        guard let booking = try modelContext.fetch(bookingDescriptor).first else {
            throw RepositoryError.notFound("Booking \(bookingID)")
        }
        if let tripID {
            let tripDescriptor = FetchDescriptor<SDTrip>(predicate: #Predicate { $0.id == tripID })
            guard let trip = try modelContext.fetch(tripDescriptor).first else {
                throw RepositoryError.notFound("Trip \(tripID)")
            }
            booking.trip = trip
        } else {
            booking.trip = nil
        }
    }

    public func save() throws {
        do {
            try modelContext.save()
        } catch {
            throw RepositoryError.persistenceFailed(String(describing: error))
        }
    }
}
